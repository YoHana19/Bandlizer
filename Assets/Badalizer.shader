Shader "Geometry/Badalizer"
{
    Properties
    {
        _MainTex("Texture", 2D) = "white" {}
		[HDR] _EmissionColor1("EmissionColor1", Color) = (0.0, 0.0, 0.0, 0.0)
		[HDR] _EmissionColor2("EmissionColor2", Color) = (0.0, 0.0, 0.0, 0.0)
		_Radius("Raidus", Range(0.1, 3.0)) = 1.0
		_HueShift("HueShift", Range(0.0, 1.0)) = 0.2
		_Density("Density", Range(0.0, 1.0)) = 0.05
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
			#pragma geometry geom
            #pragma fragment frag
            #include "UnityCG.cginc"
			#include "Badalizer.cginc"
            ENDCG
        }
    }
}
