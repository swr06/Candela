//#define STACKLESS

// If stack-ed traversal is wanted, then undefine the above.

#ifdef STACKLESS

	#include "Intersectors/Include/TraverseBVHStackless.glsl"

#else 

	#include "Intersectors/Include/TraverseBVHStack.glsl"

#endif


//////////////////////////////