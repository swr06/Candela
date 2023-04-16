// Tweak these as you like  
// (This is temporary for now)

//#define WHITISH_COLORS
#define YELLOWISH_COLORS
 




// Colors are more white 
#ifdef WHITISH_COLORS 

// Color of the sun for direct lighting 
#define SUN_COLOR_LIGHTING (vec3(255.) / 255.0f) * 17.0f 

// Sun lighting for the probes (This color affects the second bounce and the indirect volumetrics 
#define SUN_COLOR_PROBES (vec3(255.) / 255.0f) * 17.0f 

// Sun color for diffuse indirect
#define SUN_COLOR_DIFF (vec3(255.) / 255.0f) * 17.0f 

// Sun color for specular indirect
#define SUN_COLOR_SPEC (vec3(255.) / 255.0f) * 17.0f 

// Color of the sun for the direct volumetrics
#define VOL_SUN_COLOR  (vec3(253.0f, 184.0f, 160.0f) / 255.0f) * 0.19f * 2.0f * 0.35f

#elif defined(YELLOWISH_COLORS)

// Colors are yellowish

// Color of the sun for direct lighting 
#define SUN_COLOR_LIGHTING (vec3(253.0f, 184.0f, 170.0f) / 255.0f) * 17.0f 

// Sun lighting for the probes (This color affects the second bounce and the indirect volumetrics 
#define SUN_COLOR_PROBES (vec3(253.0f, 184.0f, 170.0f) / 255.0f) * 17.0f 

// Sun color for diffuse indirect
#define SUN_COLOR_DIFF (vec3(253.0f, 184.0f, 170.0f) / 255.0f) * 17.0f 

// Sun color for specular indirect
#define SUN_COLOR_SPEC (vec3(253.0f, 184.0f, 170.0f) / 255.0f) * 17.0f 

// Color of the sun for the direct volumetrics
#define VOL_SUN_COLOR  (vec3(253.0f, 184.0f, 125.0f) / 255.0f) * 0.19f * 2.0f * 0.35f

#else 

// This color was gotten by using a blackbody transform to get a color for 5800K
#define BlackBodySunColor vec3(0.99999f, 0.894396, 0.800553)

// Color of the sun for direct lighting 
#define SUN_COLOR_LIGHTING (BlackBodySunColor) * 17.0f 

// Sun lighting for the probes (This color affects the second bounce and the indirect volumetrics 
#define SUN_COLOR_PROBES (BlackBodySunColor) * 17.0f 

// Sun color for diffuse indirect
#define SUN_COLOR_DIFF (BlackBodySunColor) * 17.0f 

// Sun color for specular indirect
#define SUN_COLOR_SPEC (BlackBodySunColor) * 17.0f 

// Color of the sun for the direct volumetrics
#define VOL_SUN_COLOR  (BlackBodySunColor) * 0.19f * 2.0f * 0.35f

#endif


// Notes 
// 253.0f, 184.0f, 100.0f ---- Yellow-Orangish sun 
