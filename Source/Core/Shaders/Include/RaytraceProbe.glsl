// include Utility.glsl

int GetFaceID(vec3 Direction)
{
    vec3 AbsoluteDirection = abs(Direction);
    float Index = 0.0f;

	if(AbsoluteDirection.z >= AbsoluteDirection.x && AbsoluteDirection.z >= AbsoluteDirection.y)
	{
		Index = Direction.z < 0.0 ? 5.0 : 4.0;
	}

	else if(AbsoluteDirection.y >= AbsoluteDirection.x)
	{
		Index = Direction.y < 0.0 ? 3.0 : 2.0;
	}

	else
	{
		Index = Direction.x < 0.0 ? 1.0 : 0.0;
	}

    return int(Index);
}

vec3 GetCapturePoint(vec3 Direction, in vec3 ProbePoints[6]) {
    return ProbePoints[clamp(GetFaceID(Direction),0,5)];
}

float DistanceSqr(vec3 A, vec3 B)
{
    vec3 C = A - B;
    return dot(C, C);
}


GBufferData RaytraceProbe(samplerCube ProbeDepth, samplerCube ProbeAlbedo, samplerCube ProbeNormals, vec3 WorldPosition, vec3 Direction, float ErrorTolerance, float Hash, int Steps, int BinarySteps, in vec3 ProbePoints[6]) {
   
    // Settings 

    const float Distance = 32.0f; 

    float StepSize = Distance / float(Steps);

    vec3 ReflectionVector = Direction; 
    
    vec3 RayPosition = WorldPosition + ReflectionVector * Hash * StepSize;
    vec3 RayOrigin = RayPosition;

    vec3 PreviousSampleDirection = ReflectionVector;

    bool FoundHit = false;

    // Exponential stepping 
    float ExpStep = mix(1.0f, 1.025f, Hash);

    float SkyAmount = 0.0f;
    float DepthFinal = 0.0f;

    // Find intersection with geometry 
    // Todo : Account for geometrical thickness?
    for (int CurrentStep = 0; CurrentStep < Steps ; CurrentStep++) 
    {
        vec3 CapturePoint = GetCapturePoint(PreviousSampleDirection, ProbePoints);
        vec3 Diff = RayPosition - CapturePoint;
        float L = length(Diff);
        vec3 SampleDirection = Diff / L;
        PreviousSampleDirection = SampleDirection;
        DepthFinal = (texture(ProbeDepth, SampleDirection).x * 128.0f);

        if (DepthFinal < 0.0001f || DepthFinal == 0.0f) {
            SkyAmount += (2.0f / float(Steps));
            DepthFinal = 10000.0f;
        }


        if (L > DepthFinal) {
             FoundHit = true;
             break;
        }

        RayPosition += ReflectionVector * StepSize;
        StepSize *= ExpStep;
    }

    if (FoundHit) 
    {
        // Do a basic ssr-style binary search along intersection step and find best intersection point 

        const bool DoBinaryRefinement = true;

        vec3 FinalBinaryRefinePos = RayPosition;

        if (DoBinaryRefinement) {

            float BR_StepSize = StepSize;
            FinalBinaryRefinePos -= ReflectionVector * StepSize; // We already know that L > d

            for (int BinaryRefine = 1 ; BinaryRefine < BinarySteps; BinaryRefine++) 
            {
                BR_StepSize /= 2.0f;

                vec3 CapturePoint = GetCapturePoint(PreviousSampleDirection, ProbePoints);
                vec3 Diff = FinalBinaryRefinePos - CapturePoint;
                float L = length(Diff);
                PreviousSampleDirection = Diff / L;

                DepthFinal = (texture(ProbeDepth, PreviousSampleDirection).x * 128.0f);
                FinalBinaryRefinePos += ReflectionVector * BR_StepSize * sign(DepthFinal - L);

            }
        }

        vec3 CapturePoint = GetCapturePoint(PreviousSampleDirection, ProbePoints);
        vec3 FinalVector = FinalBinaryRefinePos - CapturePoint;
        float FinalLength = length(FinalVector);
        vec3 FinalSampleDirection = FinalVector / FinalLength;


        float DepthFetch = DepthFinal;
        vec4 AlbedoFetch = textureLod(ProbeAlbedo, FinalSampleDirection, 0.0f) * 1.0f;
        vec4 NormalFetch = textureLod(ProbeNormals, FinalSampleDirection, 0.0f);

        float DepthError = abs(DepthFetch - FinalLength);

        if (DepthError < StepSize * 0.5f) 
        {

            GBufferData ReturnValue;
            ReturnValue.Position = (CapturePoint + DepthFetch * FinalSampleDirection);
            ReturnValue.Normal = normalize(NormalFetch.xyz);
            ReturnValue.Albedo = AlbedoFetch.xyz;
            //ReturnValue.Data = vec3(AlbedoFetch.w, 0.0f, 1.0f);
            ReturnValue.ValidMask = true;
            ReturnValue.Depth = DepthFetch;

            // Emission
            ReturnValue.SkyAmount = 0.0f;

            return ReturnValue;
        }

    }


    // No hit found, return black color

    GBufferData ReturnValue;
    ReturnValue.Position = vec3(RayOrigin) + ReflectionVector * 120.0f;
    ReturnValue.Normal = vec3(-1.0f);
    ReturnValue.Albedo = vec3(-1.0f);
    //ReturnValue.Data = vec3(0.0f, 0.0f, 1.0f);
    ReturnValue.ValidMask = false;
    ReturnValue.SkyAmount = SkyAmount;
    ReturnValue.Depth = 10000.;

    return ReturnValue;
}


GBufferData RaytraceProbeOcclusion(samplerCube ProbeDepth,vec3 WorldPosition, vec3 Direction, float ErrorTolerance, float Hash, int Steps, int BinarySteps, in vec3 ProbePoints[6]) {
   
    // Settings 

    const float Distance = 32.0f; 

    float StepSize = Distance / float(Steps);

    vec3 ReflectionVector = Direction; 
    
    vec3 RayPosition = WorldPosition + ReflectionVector * Hash * StepSize;
    vec3 RayOrigin = RayPosition;

    vec3 PreviousSampleDirection = ReflectionVector;

    bool FoundHit = false;

    // Exponential stepping 
    float ExpStep = mix(1.0f, 1.025f, Hash);

    float SkyAmount = 0.0f;
    float DepthFinal = 0.0f;

    // Find intersection with geometry 
    // Todo : Account for geometrical thickness?
    for (int CurrentStep = 0; CurrentStep < Steps ; CurrentStep++) 
    {
        vec3 CapturePoint = GetCapturePoint(PreviousSampleDirection, ProbePoints);
        vec3 Diff = RayPosition - CapturePoint;
        float L = length(Diff);
        vec3 SampleDirection = Diff / L;
        PreviousSampleDirection = SampleDirection;
        DepthFinal = (texture(ProbeDepth, SampleDirection).x * 128.0f);

        if (DepthFinal < 0.0001f || DepthFinal == 0.0f) {
            SkyAmount += (2.0f / float(Steps));
            DepthFinal = 10000.0f;
        }


        if (L > DepthFinal) {
             FoundHit = true;
             break;
        }

        RayPosition += ReflectionVector * StepSize;
        StepSize *= ExpStep;
    }

    if (FoundHit) 
    {
        // Do a basic ssr-style binary search along intersection step and find best intersection point 

        const bool DoBinaryRefinement = true;

        vec3 FinalBinaryRefinePos = RayPosition;

        if (DoBinaryRefinement) {

            float BR_StepSize = StepSize;
            FinalBinaryRefinePos -= ReflectionVector * StepSize; // We already know that L > d

            for (int BinaryRefine = 1 ; BinaryRefine < BinarySteps; BinaryRefine++) 
            {
                BR_StepSize /= 2.0f;

                vec3 CapturePoint = GetCapturePoint(PreviousSampleDirection, ProbePoints);
                vec3 Diff = FinalBinaryRefinePos - CapturePoint;
                float L = length(Diff);
                PreviousSampleDirection = Diff / L;

                DepthFinal = (texture(ProbeDepth, PreviousSampleDirection).x * 128.0f);
                FinalBinaryRefinePos += ReflectionVector * BR_StepSize * sign(DepthFinal - L);

            }
        }

        vec3 CapturePoint = GetCapturePoint(PreviousSampleDirection, ProbePoints);
        vec3 FinalVector = FinalBinaryRefinePos - CapturePoint;
        float FinalLength = length(FinalVector);
        vec3 FinalSampleDirection = FinalVector / FinalLength;


        float DepthFetch = DepthFinal;

        float DepthError = abs(DepthFetch - FinalLength);

        if (DepthError < StepSize * 0.5f) 
        {

            GBufferData ReturnValue;
            ReturnValue.Position = (CapturePoint + DepthFetch * FinalSampleDirection);
            ReturnValue.Normal = vec3(-1.0f);
            ReturnValue.Albedo = vec3(-1.0f);
            //ReturnValue.Data = vec3(AlbedoFetch.w, 0.0f, 1.0f);
            ReturnValue.ValidMask = true;
            ReturnValue.Depth = DepthFetch;

            ReturnValue.SkyAmount = 0.0f;

            return ReturnValue;
        }

    }


    // No hit found, return black color

    GBufferData ReturnValue;
    ReturnValue.Position = vec3(RayOrigin) + ReflectionVector * 120.0f;
    ReturnValue.Normal = vec3(-1.0f);
    ReturnValue.Albedo = vec3(-1.0f);
    //ReturnValue.Data = vec3(0.0f, 0.0f, 1.0f);
    ReturnValue.ValidMask = false;
    ReturnValue.SkyAmount = SkyAmount;
    ReturnValue.Depth = 10000.;

    return ReturnValue;
}





float RaytraceProbeOcclusionFast(samplerCube ProbeDepth,vec3 WorldPosition, vec3 Direction, float Distance, float ErrorTolerance, float Hash, int Steps, int BinarySteps, in vec3 ProbePoints[6]) {
   
    // Settings 

    float StepSize = Distance / float(Steps);

    vec3 ReflectionVector = Direction; 
    
    vec3 RayPosition = WorldPosition + ReflectionVector * Hash * StepSize;
    vec3 RayOrigin = RayPosition;

    vec3 PreviousSampleDirection = ReflectionVector;

    bool FoundHit = false;

    // Exponential stepping 
    float ExpStep = mix(1.0f, 1.025f, Hash);

    float SkyAmount = 0.0f;
    float DepthFinal = 0.0f;

    // Find intersection with geometry 
    // Todo : Account for geometrical thickness?
    for (int CurrentStep = 0; CurrentStep < Steps ; CurrentStep++) 
    {
        vec3 CapturePoint = GetCapturePoint(PreviousSampleDirection, ProbePoints);
        vec3 Diff = RayPosition - CapturePoint;
        float L = length(Diff);
        vec3 SampleDirection = Diff / L;
        PreviousSampleDirection = SampleDirection;
        DepthFinal = (texture(ProbeDepth, SampleDirection).x * 128.0f);

        if (DepthFinal < 0.0001f || DepthFinal == 0.0f) {
            SkyAmount += (2.0f / float(Steps));
            DepthFinal = 10000.0f;
        }


        if (L > DepthFinal) {
             FoundHit = true;
             break;
        }

        RayPosition += ReflectionVector * StepSize;
        StepSize *= ExpStep;
    }

    if (FoundHit) 
    {
        const bool DoBinaryRefinement = true;

        vec3 FinalBinaryRefinePos = RayPosition;

        if (DoBinaryRefinement) {

            float BR_StepSize = StepSize;
            FinalBinaryRefinePos -= ReflectionVector * StepSize; // We already know that L > d

            for (int BinaryRefine = 1 ; BinaryRefine < BinarySteps; BinaryRefine++) 
            {
                BR_StepSize /= 2.0f;

                vec3 CapturePoint = GetCapturePoint(PreviousSampleDirection, ProbePoints);
                vec3 Diff = FinalBinaryRefinePos - CapturePoint;
                float L = length(Diff);
                PreviousSampleDirection = Diff / L;

                DepthFinal = (texture(ProbeDepth, PreviousSampleDirection).x * 128.0f);
                FinalBinaryRefinePos += ReflectionVector * BR_StepSize * sign(DepthFinal - L);

            }
        }

        vec3 CapturePoint = GetCapturePoint(PreviousSampleDirection, ProbePoints);
        vec3 FinalVector = FinalBinaryRefinePos - CapturePoint;
        float FinalLength = length(FinalVector);
        vec3 FinalSampleDirection = FinalVector / FinalLength;


        float DepthFetch = DepthFinal;

        float DepthError = abs(DepthFetch - FinalLength);

        if (DepthError < StepSize * 0.5f) 
        {
            vec3 Position = (CapturePoint + DepthFetch * FinalSampleDirection);
            float Transversal = distance(Position, RayOrigin);
            return Transversal;
        }

    }

       
    return -1.0f;
}

float RaytraceProbeOcclusionShadowShort(samplerCube ProbeDepth,vec3 WorldPosition, vec3 Direction, float Distance, float Hash, int Steps, in vec3 ProbePoints[6]) {
   
    // Settings 

    float StepSize = Distance / float(Steps);

    vec3 ReflectionVector = Direction; 
    
    vec3 RayPosition = WorldPosition + ReflectionVector * 0.5f * StepSize * Hash;
    vec3 RayOrigin = RayPosition;

    vec3 PreviousSampleDirection = ReflectionVector;

    bool FoundHit = false;

    float SkyAmount = 0.0f;
    float DepthFinal = 0.0f;

    float ExpStep = 1.0f;

    // Find intersection with geometry 
    // Todo : Account for geometrical thickness?
    for (int CurrentStep = 0; CurrentStep < Steps ; CurrentStep++) 
    {
        vec3 CapturePoint = GetCapturePoint(PreviousSampleDirection, ProbePoints);
        vec3 Diff = RayPosition - CapturePoint;
        float L = length(Diff);
        vec3 SampleDirection = Diff / L;
        PreviousSampleDirection = SampleDirection;
        DepthFinal = (texture(ProbeDepth, SampleDirection).x * 128.0f);

        if (DepthFinal < 0.0001f || DepthFinal == 0.0f) {
            SkyAmount += (2.0f / float(Steps));
            DepthFinal = 10000.0f;
        }

        float Error = abs(L - DepthFinal);

        if (L > DepthFinal && Error < StepSize * 2.5f) {
             FoundHit = true;
             return distance(RayPosition, RayOrigin);
        }

        RayPosition += ReflectionVector * StepSize;
       // StepSize *= ExpStep;
    }

    return -1.0f;
}