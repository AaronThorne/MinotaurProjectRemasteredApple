#import <UIKit/UIKit.h>
#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES2/gl.h>
#import <objc/runtime.h>
#include "SDL.h"
#include <math.h>

extern uint32_t mpr_screen_framebuffer(void);
extern void mpr_prepare_present(void);
static char programKey;

/* Opt-in render verification for device tests; absent from normal gameplay. */
void mpr_capture_test_frame(void) {
    int width,height;SDL_GL_GetDrawableSize(SDL_GL_GetCurrentWindow(),&width,&height);
    size_t stride=(size_t)width*4,size=stride*height;
    unsigned char *pixels=malloc(size),*flipped=malloc(size);
    glReadPixels(0,0,width,height,GL_RGBA,GL_UNSIGNED_BYTE,pixels);
    for(int y=0;y<height;y++)memcpy(flipped+y*stride,pixels+(height-1-y)*stride,stride);
    CGColorSpaceRef color=CGColorSpaceCreateDeviceRGB();
    CGContextRef context=CGBitmapContextCreate(flipped,width,height,8,stride,color,kCGImageAlphaPremultipliedLast|kCGBitmapByteOrder32Big);
    CGImageRef image=CGBitmapContextCreateImage(context);
    NSData *png=UIImagePNGRepresentation([UIImage imageWithCGImage:image]);
    NSString *game=getenv("MPR_GAME_ID")?@(getenv("MPR_GAME_ID")):@"SmokeFrame";
    [png writeToFile:[NSHomeDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"Documents/%@.png",game]] atomically:YES];
    CGImageRelease(image);CGContextRelease(context);CGColorSpaceRelease(color);free(pixels);free(flipped);
    NSLog(@"Saved device render verification frame");
}

static GLuint shader(GLenum type,const char *source) {
    GLuint result=glCreateShader(type);glShaderSource(result,1,&source,NULL);glCompileShader(result);
    GLint valid=0;glGetShaderiv(result,GL_COMPILE_STATUS,&valid);
    if(!valid){char log[2048];glGetShaderInfoLog(result,sizeof(log),NULL,log);NSLog(@"Presenter shader: %s",log);abort();}
    return result;
}

/* Draw the guest renderbuffer with ES2 shaders. Restore every modified guest state. */
void mpr_present_es2(GLuint renderbuffer,GLint x,GLint y,GLsizei width,GLsizei height,
                     GLint vx,GLint vy,GLsizei vw,GLsizei vh,const float *rotation,int nearest,
                     const float *cursor) {
    GLint program,active,texture,framebuffer,arrayBuffer,renderBuffer,viewport[4];
    GLfloat clear[4];GLboolean mask[4];
    glGetIntegerv(GL_CURRENT_PROGRAM,&program);glGetIntegerv(GL_ACTIVE_TEXTURE,&active);
    glActiveTexture(GL_TEXTURE0);glGetIntegerv(GL_TEXTURE_BINDING_2D,&texture);
    glGetIntegerv(GL_FRAMEBUFFER_BINDING,&framebuffer);glGetIntegerv(GL_RENDERBUFFER_BINDING,&renderBuffer);
    glGetIntegerv(GL_ARRAY_BUFFER_BINDING,&arrayBuffer);glGetIntegerv(GL_VIEWPORT,viewport);
    glGetFloatv(GL_COLOR_CLEAR_VALUE,clear);glGetBooleanv(GL_COLOR_WRITEMASK,mask);
    GLenum caps[]={GL_BLEND,GL_CULL_FACE,GL_DEPTH_TEST,GL_STENCIL_TEST,GL_SCISSOR_TEST};
    GLboolean enabled[5];for(int i=0;i<5;i++){enabled[i]=glIsEnabled(caps[i]);glDisable(caps[i]);}
    struct {GLint enabled,size,type,normalized,stride,buffer;void *pointer;} attributes[2];
    for(int i=0;i<2;i++){
        glGetVertexAttribiv(i,GL_VERTEX_ATTRIB_ARRAY_ENABLED,&attributes[i].enabled);
        glGetVertexAttribiv(i,GL_VERTEX_ATTRIB_ARRAY_SIZE,&attributes[i].size);
        glGetVertexAttribiv(i,GL_VERTEX_ATTRIB_ARRAY_TYPE,&attributes[i].type);
        glGetVertexAttribiv(i,GL_VERTEX_ATTRIB_ARRAY_NORMALIZED,&attributes[i].normalized);
        glGetVertexAttribiv(i,GL_VERTEX_ATTRIB_ARRAY_STRIDE,&attributes[i].stride);
        glGetVertexAttribiv(i,GL_VERTEX_ATTRIB_ARRAY_BUFFER_BINDING,&attributes[i].buffer);
        glGetVertexAttribPointerv(i,GL_VERTEX_ATTRIB_ARRAY_POINTER,&attributes[i].pointer);
    }
    NSNumber *cached=objc_getAssociatedObject(EAGLContext.currentContext,&programKey);
    GLuint copyProgram=cached.unsignedIntValue;
    if(!copyProgram){
        if(getenv("MPR_CAPTURE_FRAME")) {
            int dw,dh;SDL_GL_GetDrawableSize(SDL_GL_GetCurrentWindow(),&dw,&dh);
            NSLog(@"Game display: source %dx%d at %d,%d; viewport %d,%d %dx%d; drawable %dx%d",width,height,x,y,vx,vy,vw,vh,dw,dh);
        }
        GLuint vertex=shader(GL_VERTEX_SHADER,"attribute vec2 position;attribute vec2 uv;varying vec2 texcoord;void main(){gl_Position=vec4(position,0.0,1.0);texcoord=uv;}");
        GLuint fragment=shader(GL_FRAGMENT_SHADER,
            "precision highp float;"
            "varying vec2 texcoord;uniform sampler2D frame;uniform vec4 cursor;"
            "void main(){"
            "vec4 color=texture2D(frame,texcoord);"
            "if(cursor.z>0.0){"
            "float d=distance(gl_FragCoord.xy,cursor.xy);"
            "if(d<cursor.z)color=vec4(d>cursor.z*0.55?vec3(1.0):vec3(0.05+cursor.w*0.25),1.0);"
            "}"
            "gl_FragColor=color;"
            "}");
        copyProgram=glCreateProgram();glAttachShader(copyProgram,vertex);glAttachShader(copyProgram,fragment);
        glBindAttribLocation(copyProgram,0,"position");glBindAttribLocation(copyProgram,1,"uv");glLinkProgram(copyProgram);
        glDeleteShader(vertex);glDeleteShader(fragment);
        GLint linked=0;glGetProgramiv(copyProgram,GL_LINK_STATUS,&linked);if(!linked)abort();
        objc_setAssociatedObject(EAGLContext.currentContext,&programKey,@(copyProgram),OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    GLuint source=0,copy=0;glGenFramebuffers(1,&source);glBindFramebuffer(GL_FRAMEBUFFER,source);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER,GL_COLOR_ATTACHMENT0,GL_RENDERBUFFER,renderbuffer);
    glGenTextures(1,&copy);glBindTexture(GL_TEXTURE_2D,copy);
    glCopyTexImage2D(GL_TEXTURE_2D,0,GL_RGBA,x,y,width,height,0);
    glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MIN_FILTER,nearest?GL_NEAREST:GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MAG_FILTER,nearest?GL_NEAREST:GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_WRAP_S,GL_CLAMP_TO_EDGE);glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_WRAP_T,GL_CLAMP_TO_EDGE);
    glBindFramebuffer(GL_FRAMEBUFFER,mpr_screen_framebuffer());
    glColorMask(GL_TRUE,GL_TRUE,GL_TRUE,GL_TRUE);glClearColor(0,0,0,1);glClear(GL_COLOR_BUFFER_BIT);
    glViewport(vx,vy,vw,vh);glUseProgram(copyProgram);glUniform1i(glGetUniformLocation(copyProgram,"frame"),0);
    const GLint cursorUniform=glGetUniformLocation(copyProgram,"cursor");
    if (cursor) {
        GLfloat radius=fmaxf(8.0f,vh/768.0f*12.0f);
        glUniform4f(cursorUniform,cursor[0],2.0f*vy+vh-cursor[1],radius,cursor[2]);
    } else {
        glUniform4f(cursorUniform,0,0,0,0);
    }
    GLfloat vertices[]={-1,-1,1,-1,-1,1,1,1};GLfloat uv[]={0,0,1,0,0,1,1,1};
    for(int i=0;i<4;i++){float u=uv[2*i]-.5f,v=uv[2*i+1]-.5f;uv[2*i]=rotation[0]*u+rotation[2]*v+.5f;uv[2*i+1]=rotation[1]*u+rotation[3]*v+.5f;}
    glBindBuffer(GL_ARRAY_BUFFER,0);glEnableVertexAttribArray(0);glEnableVertexAttribArray(1);
    glVertexAttribPointer(0,2,GL_FLOAT,GL_FALSE,0,vertices);glVertexAttribPointer(1,2,GL_FLOAT,GL_FALSE,0,uv);
    glDrawArrays(GL_TRIANGLE_STRIP,0,4);
    mpr_prepare_present();SDL_GL_SwapWindow(SDL_GL_GetCurrentWindow());
    glDeleteTextures(1,&copy);glDeleteFramebuffers(1,&source);
    for(int i=0;i<2;i++){
        glBindBuffer(GL_ARRAY_BUFFER,attributes[i].buffer);
        glVertexAttribPointer(i,attributes[i].size,attributes[i].type,attributes[i].normalized,attributes[i].stride,attributes[i].pointer);
        if(attributes[i].enabled)glEnableVertexAttribArray(i);else glDisableVertexAttribArray(i);
    }
    glBindBuffer(GL_ARRAY_BUFFER,arrayBuffer);glUseProgram(program);
    glBindTexture(GL_TEXTURE_2D,texture);glActiveTexture(active);
    glBindFramebuffer(GL_FRAMEBUFFER,framebuffer);glBindRenderbuffer(GL_RENDERBUFFER,renderBuffer);
    glViewport(viewport[0],viewport[1],viewport[2],viewport[3]);glClearColor(clear[0],clear[1],clear[2],clear[3]);glColorMask(mask[0],mask[1],mask[2],mask[3]);
    for(int i=0;i<5;i++)if(enabled[i])glEnable(caps[i]);
}
