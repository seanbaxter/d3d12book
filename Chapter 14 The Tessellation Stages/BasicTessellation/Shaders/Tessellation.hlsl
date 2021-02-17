
// Constant data that varies per frame.
cbuffer cbPerObject : register(b0)
{
	float4x4 gWorld;
};

// Constant data that varies per material.
cbuffer cbPass : register(b1)
{
	float4x4 gViewProj;
	float3 gEyePosW;
};

struct VertexIn
{
	float3 PosL    : location;
};

struct VertexOut
{
	float4 PosL    : SV_Position;
};

VertexOut VS(VertexIn vin)
{
	VertexOut vout;
	
	vout.PosL = float4(vin.PosL, 1);

	return vout;
}
 
struct PatchTess
{
	float EdgeTess[4]   : SV_TessFactor;
	float InsideTess[2] : SV_InsideTessFactor;
};

PatchTess ConstantHS(InputPatch<VertexOut, 4> patch)
{
	PatchTess pt;
	
	float3 p0 = patch[0].PosL.xyz;
	float3 p1 = patch[1].PosL.xyz;
	float3 p2 = patch[2].PosL.xyz;
	float3 p3 = patch[3].PosL.xyz;
	float3 centerL = 0.25f*(p0 + p1 + p2 + p3);
	float3 centerW = mul(float4(centerL, 1.0f), gWorld).xyz;
	
	float d = distance(centerW, gEyePosW);

	// Tessellate the patch based on distance from the eye such that
	// the tessellation is 0 if d >= d1 and 64 if d <= d0.  The interval
	// [d0, d1] defines the range we tessellate in.
	
	const float d0 = 20.0f;
	const float d1 = 100.0f;
	float tess = 64.0f*saturate( (d1-d)/(d1-d0) );

	// Uniformly tessellate the patch.

	pt.EdgeTess[0] = tess;
	pt.EdgeTess[1] = tess;
	pt.EdgeTess[2] = tess;
	pt.EdgeTess[3] = tess;
	
	pt.InsideTess[0] = tess;
	pt.InsideTess[1] = tess;
	
	return pt;
}

struct HullOut
{
	float4 PosL : SV_Position;
};

[domain("quad")]
[partitioning("fractional_even")]
[outputtopology("triangle_cw")]
[outputcontrolpoints(4)]
[patchconstantfunc("ConstantHS")]
[maxtessfactor(64.0f)]
HullOut HS(InputPatch<VertexOut, 4> p, 
           uint i : SV_OutputControlPointID)
{
	HullOut hout;
	
	hout.PosL = p[i].PosL;
	
	return hout;
}

struct DomainOut
{
	float4 PosH : SV_Position;
};

// The domain shader is called for every vertex created by the tessellator.  
// It is like the vertex shader after tessellation.
[domain("quad")]
DomainOut DS(PatchTess patchTess, 
             float2 uv : SV_DomainLocation, 
             const OutputPatch<HullOut, 4> quad)
{
	DomainOut dout;
	
	// Bilinear interpolation.
	float3 v1 = lerp(quad[0].PosL.xyz, quad[1].PosL.xyz, uv.x); 
	float3 v2 = lerp(quad[2].PosL.xyz, quad[3].PosL.xyz, uv.x); 
	float3 p  = lerp(v1, v2, uv.y); 
	
	// Displacement mapping
	p.y = 0.3f*( p.z*sin(p.x) + p.x*cos(p.z) );
	
	float4 posW = mul(float4(p, 1.0f), gWorld);
	dout.PosH = mul(posW, gViewProj);
	
	return dout;
}

float4 PS(DomainOut pin) : SV_Target
{
    return float4(1.0f, 1.0f, 1.0f, 1.0f);
}
