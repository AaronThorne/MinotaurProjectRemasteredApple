import hashlib,importlib.util,io,plistlib,struct,tempfile,unittest,zipfile
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('import_assets',ROOT/'scripts/import_assets.py')
module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)

class AssetImportTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.original_out=module.OUT;self.original_ids=module.BY_ID
        module.OUT=Path(self.temp.name)
        self.raw=b'\xce\xfa\xed\xfe'+bytes(60)
        self.game={'id':'Synthetic','title':'Synthetic fixture','bundle_id':'test.fixture','arm32_sha256':hashlib.sha256(self.raw).hexdigest()}
        module.BY_ID={'test.fixture':self.game}
    def tearDown(self):
        module.OUT=self.original_out;module.BY_ID=self.original_ids;self.temp.cleanup()
    def ipa(self,raw=None):
        output=io.BytesIO()
        with zipfile.ZipFile(output,'w') as z:
            z.writestr('Payload/Test.app/Info.plist',plistlib.dumps({'CFBundleIdentifier':'test.fixture','CFBundleExecutable':'Test'}))
            z.writestr('Payload/Test.app/Test',self.raw if raw is None else raw)
        return output.getvalue()
    def test_import_identifies_by_bundle_and_preserves_archive(self):
        data=self.ipa();self.assertEqual(module.read_ipa(data),self.game)
        self.assertEqual((module.OUT/'ipas/Synthetic.ipa').read_bytes(),data)
    def test_other_binary_revision_is_rejected(self):
        with self.assertRaisesRegex(ValueError,'unsupported/encrypted'):module.read_ipa(self.ipa(b'wrong version'))
        self.assertFalse((module.OUT/'ipas/Synthetic.ipa').exists())
    def test_embedded_archive_with_executable_prefix_is_recovered(self):
        self.assertEqual(module.embedded_ipa(b'MZ'+bytes(100)+self.ipa()+b'padding'),self.game)
    def test_release_path_traversal_is_rejected(self):
        archive=module.OUT/'bad.zip'
        with zipfile.ZipFile(archive,'w') as z:z.writestr('../escape','bad')
        with self.assertRaisesRegex(ValueError,'leaves extraction'):module.import_release(archive)

if __name__=='__main__':unittest.main()
