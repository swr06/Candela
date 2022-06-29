#define STACKLESS

// If stack-ed traversal is wanted, then undefine the above.

#ifdef STACKLESS

	#ifdef BVH_COLLISION

		#include "Intersectors/Include/CollideBVHStackless.glsl"

	#else 

		#include "Intersectors/Include/TraverseBVHStackless.glsl"

	#endif

#else 

	#ifdef BVH_COLLISION

		#include "Intersectors/Include/CollideBVHStack.glsl"

	#else 

		#include "Intersectors/Include/TraverseBVHStack.glsl"

	#endif

#endif


//////////////////////////////