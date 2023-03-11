<!-- Allow this file to not have a first line heading -->
<!-- markdownlint-disable-file MD041 -->

<!-- inline html -->
<!-- markdownlint-disable-file MD033 -->

<div align="center">

# The Candela Engine
  
<img src="https://github.com/swr06/Candela/blob/MainBranch/Branding/logo.png" data-canonical-src="https://github.com/swr06/Candela/blob/MainBranch/Branding/logo.png" width="240" height="240" />
  
</div>

# Current Feature List 
- Model loading, abstracted program/application API
- Procedural Normal Map Generation (Using sobel operator)
- Custom SAH BVH Constructor and Ray Intersection API
- Support for Stack/Stackless BVH traversal
- Physically based direct lighting (Cook Torrance BRDF)
- Cascaded Shadow Mapping + PCF
- Indirect Diffuse GI
- Infinite bounce GI using irradiance probes
- Hemispherical Shadow Maps for a sky shadowing approximation
- Hybrid Specular GI (SSR + World Space RT)
- SVGF + Specialized Specular Denoiser
- Temporal Anti Aliasing + Upscaling
- Fast Approximate Anti Aliasing (Based on FXAA 3.11 by Nvidia)
- Spatial Image Upscaling (Custom CAS + AMD FSR EASU)
- Volumetrics (Direct + Indirect light contribution)
- Upscaling (Temporal/Spatial)
- Culling (Frustum/Face Culling)
- Environment Map Support 
- Post Processing Pipeline (Bloom, DoF, Grain, Chromatic Aberration, Color Dithering, ACES Tonemapping, Procedural Lens Flare etc.)
- Basic Editor Features + Debug Views
- Transparent/Refractive Material Support (OIT / Screenspace Refraction / Screenspace caustics)

# Planned Features
- Transparent Shadows
- IES lights
- LTC
- Sky rendering

# Requirements  
A GPU with >= 2 GB of vRAM that supports OpenGL 4.5 and the bindless texture OpenGL extension (ARB_bindless_texture)

# Performance 
- Runs at around 24 fps on my AMD Vega 8 (desktop) iGPU. 

# Known Issues
- Volumetrics prone to light leaking
- Temporal/Spatial artifacts (usually in the form of noise or ghosting) on aggressive movement or disocclusions 

# Notes
- Refer `Controls.txt` for engine controls/shortcuts.
- Refer `Additional Notes.txt` for additional general info.

# Screenshots

</br>

![s1](https://github.com/swr06/Candela/blob/MainBranch/Screenshots/1.png)

</br>

</br>

![s2](https://github.com/swr06/Candela/blob/MainBranch/Screenshots/2.png)

</br>

</br>

![s3](https://github.com/swr06/Candela/blob/MainBranch/Screenshots/3.png)

</br>

</br>

![s12](https://github.com/swr06/Candela/blob/MainBranch/Screenshots/12.png)

</br>

</br>

![s13](https://github.com/swr06/Candela/blob/MainBranch/Screenshots/13.png)

</br>

</br>

![s4](https://github.com/swr06/Candela/blob/MainBranch/Screenshots/4.png)

</br>

</br>

![s5](https://github.com/swr06/Candela/blob/MainBranch/Screenshots/5.png)

</br>

</br>

![s6](https://github.com/swr06/Candela/blob/MainBranch/Screenshots/6.png)

</br>

</br>

![s7](https://github.com/swr06/Candela/blob/MainBranch/Screenshots/7.png)

</br>

</br>

![s8](https://github.com/swr06/Candela/blob/MainBranch/Screenshots/8.png)

</br>

</br>

![s9](https://github.com/swr06/Candela/blob/MainBranch/Screenshots/9.png)

</br>


</br>

![s10](https://github.com/swr06/Candela/blob/MainBranch/Screenshots/10.png)

</br>

</br>

![s14](https://github.com/swr06/Candela/blob/MainBranch/Screenshots/14.png)

</br>

# Supporting

If you like this project and would like to show your support, please consider starring the project on github. :)
