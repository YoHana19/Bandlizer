#ifndef Badalizer_INCLUDED
#define Badalizer_INCLUDED

#include "Common.cginc"
#include "SimplexNoise2D.hlsl"

sampler2D _MainTex;
float4 _MainTex_ST;
float4 _EmissionColor1;
float4 _EmissionColor2;
float4 _EffectVector;
float _Radius;
float _HueShift;
float _Density;

struct appdata
{
	float4 vertex : POSITION;
	float3 normal : NORMAL;
	float2 uv : TEXCOORD0;
};

struct g2f
{
	float4 vertex : SV_POSITION;
	float2 uv : TEXCOORD0;
	float2 emPower : TEXCOORD1;
};

appdata vert(appdata v)
{
	v.vertex = mul(unity_ObjectToWorld, v.vertex);
	v.normal = UnityObjectToWorldNormal(v.normal);
	return v;
}

#define POINTS_PER_RING 24

float3 RingPoint(float3 tx, float3 ty, float phi, float2 np)
{
	return (cos(phi) * tx + sin(phi) * ty) * (1 + snoise(np) * 0.2);
}

g2f VertexOutput(float3 wpos, float2 uv, float param = 1)
{
	g2f o;
	o.vertex = UnityWorldToClipPos(float4(wpos, 1));
	o.uv = uv;
	o.emPower = float2(1 - smoothstep(0, 0.55, param), saturate(step(0.45, param) - smoothstep(0.45, 1, param)));
	return o;
}

[maxvertexcount(POINTS_PER_RING * 2)]
void geom(triangle appdata input[3], uint pid: SV_PrimitiveID, inout TriangleStream<g2f> outStream)
{
	float3 p0 = input[0].vertex.xyz;
	float3 p1 = input[1].vertex.xyz;
	float3 p2 = input[2].vertex.xyz;

	float3 n0 = input[0].normal;
	float3 n1 = input[1].normal;
	float3 n2 = input[2].normal;

	float2 uv0 = input[0].uv;
	float2 uv1 = input[1].uv;
	float2 uv2 = input[2].uv;

	float3 center = (p0 + p1 + p2) / 3;
	float2 uv = (uv0 + uv1 + uv2) / 3;

	float param = 1 - dot(_EffectVector.xyz, center) + _EffectVector.w;

	// Pass through the vertices if deformation hasn't been started yet.
	if (param < 0)
	{
		outStream.Append(VertexOutput(p0, uv0));
		outStream.Append(VertexOutput(p1, uv1));
		outStream.Append(VertexOutput(p2, uv2));
		outStream.RestartStrip();
		return;
	}

	// Draw nothing at the end of deformation.
	if (param >= 1) return;

	uint seed = pid * 877;
	if (Random(seed) < _Density)
	{
		// Construct the tangent space
		float3 tx = normalize(n0 + n1 + n2);
		float3 ty = normalize(cross(RandomVector(seed + 1), tx));
		float3 tz = normalize(cross(tx, ty));

		// Ring width
		float wid = 0.01;
		wid *= smoothstep(0, 0.2, param);
		wid *= smoothstep(0, 0.8, 1 - param);

		// Ring radius
		float rad = (1 + Random(seed + 4)) * 0.1 * _Radius;
		rad *= 1 - (1 - param) * (1 - param);

		// Noise offset
		float noffs = Random(seed + 5) * 3234.21 + param * 2;

		// Base angle
		float phi = Random(seed + 6) * UNITY_PI * 2;

		// Loop parameters
		float phi_di = UNITY_PI * 2 / POINTS_PER_RING;
		float np_di = 0.05 + 0.2 * Random(seed + 7);

		for (uint i = 0; i < POINTS_PER_RING; i++)
		{
			// Calculate three points to derive the gradient.
			float3 pBase = RingPoint(tx, ty, phi + phi_di * (i), float2(noffs, np_di));

			// Position/normal
			float3 pos = center + pBase * rad;

			// Ring width curve
			float dz = wid * smoothstep(0, 0.8, 1 - abs(1 - i / 12.0));

			// Vertex outputs
			outStream.Append(VertexOutput(pos + tz * dz, uv, param));
			outStream.Append(VertexOutput(pos - tz * dz, uv, param));
		}

		outStream.RestartStrip();
	}
	else 
	{
		// Random motion
		float3 move = RandomVector(seed + 1) * param * 0.5;

		// Random rotation
		float3 rot_angles = (RandomVector01(seed + 1) - 0.5) * 100;
		float3x3 rot_m = Euler3x3(rot_angles * param); // ‰ñ“]s—ñ‚ð¶¬

		// Simple shrink
		float scale = 1 - param;

		// Apply the animation.
		float3 t_p0 = mul(rot_m, p0 - center) * scale + center + move;
		float3 t_p1 = mul(rot_m, p1 - center) * scale + center + move;
		float3 t_p2 = mul(rot_m, p2 - center) * scale + center + move;

		// Vertex outputs
		outStream.Append(VertexOutput(t_p0, uv0, param));
		outStream.Append(VertexOutput(t_p1, uv1, param));
		outStream.Append(VertexOutput(t_p2, uv2, param));
		outStream.RestartStrip();
	}

	
}

fixed4 frag(g2f i) : SV_Target
{
	fixed4 col = tex2D(_MainTex, i.uv) +_EmissionColor1 * pow(i.emPower.x, 2) + _EmissionColor2 * pow(i.emPower.y, 2);
	
	// Emission color
	fixed4 hsl = RGB2HSL(_EmissionColor1);
	float hueShift = _HueShift * i.emPower.x;
	fixed4 emission = HSL2RGB(half4(hsl.x - hueShift, hsl.yzw));
	//col += emission * i.emPower.x;
	return col;
}
#endif