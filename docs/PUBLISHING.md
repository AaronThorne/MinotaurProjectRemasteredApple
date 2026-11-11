# Publishing this prepared repository

This is a local, reviewable source repository. Preparing it has not created a GitHub repository, pushed code, or published a binary release.

Before publishing, review the README, credits, licence scope and known issues. In particular, keep the iPhone canvas verification status explicit and do not advertise unverified iPhone gameplay as working. The prepared tree excludes original games, generated translations, build output, private saves and signing material.

To publish the source to an empty GitHub repository that you own, add that repository as the remote and push the `main` branch:

```sh
git remote add origin https://github.com/YOUR_ACCOUNT/YOUR_REPOSITORY.git
git push -u origin main
```

Do not point `origin` at the original author's repository unless you have explicitly arranged to contribute there. Credit and link the original project rather than implying this is its official Apple release.

A source ZIP and a Git bundle can also be shared. The ZIP is a source snapshot; the bundle can be cloned into a normal Git checkout with its prepared commit history. Neither includes ignored original assets.

Binary releases are a separate step: verify the intended game-asset distribution scope, preserve dependency notices, test the actual packaged apps, describe signing/notarization status, and distinguish Mac/iPad readiness from the iPhone path with startup rendering checked but fuller gameplay testing pending. Do not upload somebody else's signing keys, profiles or player data.
