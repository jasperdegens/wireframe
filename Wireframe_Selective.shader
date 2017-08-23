/* Selective Wireframe Shader
2017-08-23
Jasper Degens

Based off: http://developer.download.nvidia.com/SDK/10/direct3d/Source/SolidWireframe/Doc/SolidWireframe.pdf

*/


Shader "Custom/Wireframe_Selective"
{
	Properties
	{
		_LineWidth("Line Width", float) = 1.5
		_LineColor("Line Color", Color) = (0, 1, 0, 1)
		_FadeDistance("Fade Distance", float) = 50
		_EdgesToDraw("EdgesToDraw [1 = do not draw]", Vector) = (1, 1, 1, 0)
	}


		CGINCLUDE

#include "UnityCG.cginc"
#define FLT_MAX  3.402823466e+38F
		float _LineWidth;
	float4 _LineColor;
	float _FadeDistance;
	float4 _EdgesToDraw;

	static const uint infoA[7] = { 0, 0, 0, 0, 1, 1, 2 };
	static const uint infoB[7] = { 1, 1, 2, 0, 2, 1, 2 };
	static const uint infoAd[7] = { 2, 2, 1, 1, 0, 0, 0 };
	static const uint infoBd[7] = { 2, 2, 1, 2, 0, 2, 1 };
	static const uint infoEdge0[7] = { 0, 2, 0, 0, 0, 0, 2 };

	static const float4 ColorCases[7] = {
		{ 1, 1, 1, 1 },
		{ 1, 1, 0, 1 },
		{ 1, 0, 1, 1 },
		{ 1, 0, 0, 1 },
		{ 0, 1, 1, 1 },
		{ 0, 1, 0, 1 },
		{ 0, 0, 1, 1 }
	};

	static const uint lineNum[3] = { 0, 2, 1 };


	struct VS_INPUT
	{
		float3 Pos : POSITION;
		float3 Tex : TEXCOORD0;
	};

	struct GS_INPUT
	{
		float4 Pos  : POSITION;
	};

	struct PS_INPUT_WIRE
	{
		float4 Pos : SV_POSITION;
		float4 Col : TEXCOORD0;
		noperspective float4 EdgeA : TEXCOORD1;
		noperspective float4 EdgeB : TEXCOORD2;
		uint Case : TEXCOORD3;
	};


	/* Standard solid wirefram shader */

	// Vertex Shader -> prepare input for geometry shader
	GS_INPUT VS(VS_INPUT input)
	{
		GS_INPUT output;
		UNITY_INITIALIZE_OUTPUT(GS_INPUT, output);
		output.Pos  = UnityObjectToClipPos(float4(input.Pos, 1));
		return output;
	}
	

	float2 projToWindow(in float4 pos) 
	{
		return float2
			(
				_ScreenParams.x * 0.5 * ((pos.x / pos.w) + 1) + _ScreenParams.z,
				_ScreenParams.y * 0.5 * (1 - (pos.y / pos.w)) + _ScreenParams.w
				);
	}


	// Geometry Shader -> compute triangle coords
	[maxvertexcount(3)]
	void GS_SOLID_WIRE(triangle GS_INPUT input[3], inout TriangleStream<PS_INPUT_WIRE> outStream)
	{
		PS_INPUT_WIRE output;
		UNITY_INITIALIZE_OUTPUT(PS_INPUT_WIRE, output);

		// Compute the case from the positions of point in space.
		//output.Case = ((input[0].Pos.z < 0) || (input[0].Pos.x < -1) || (input[0].Pos.x * 4 + (input[1].Pos.z < 0) * 2 + (input[2].Pos.z < 0);
		//output.Case = (input[0].Pos.z < 0) * 4 + (input[1].Pos.z < 0) * 2 + (input[2].Pos.z < 0);
		output.Case = 
			((input[0].Pos.x < -input[0].Pos.w) || (input[0].Pos.x > input[0].Pos.w) || (input[0].Pos.y < -input[0].Pos.w) || (input[0].Pos.y > input[0].Pos.w)) * 4 +
			((input[1].Pos.x < -input[1].Pos.w) || (input[1].Pos.x > input[1].Pos.w) || (input[1].Pos.y < -input[1].Pos.w) || (input[1].Pos.y > input[1].Pos.w)) * 2 +
			((input[2].Pos.x < -input[2].Pos.w) || (input[2].Pos.x > input[2].Pos.w) || (input[2].Pos.y < -input[2].Pos.w) || (input[2].Pos.y > input[2].Pos.w));

		// If case is all vertices behind viewpoint (case = 7) then cull.
		if (output.Case == 7) return;

		// Shade and colour face just for the "all in one" technique.
		//output.Col = shadeFace(input[0].PosV, input[1].PosV, input[2].PosV);

		// Transform position to window space
		float2 points[3];
		points[0] = projToWindow(input[0].Pos);
		points[1] = projToWindow(input[1].Pos);
		points[2] = projToWindow(input[2].Pos);

		// If Case is 0, all projected points are defined, do the
		// general case computation
		if (output.Case == 0)
		{
			output.EdgeA = float4(0, 0, 0, 0);
			output.EdgeB = float4(0, 0, 0, 0);

			// Compute the edges vectors of the transformed triangle
			float2 edges[3];
			edges[0] = points[1] - points[0];
			edges[1] = points[2] - points[1];
			edges[2] = points[0] - points[2];

			// Store the length of the edges
			float lengths[3];
			lengths[0] = length(edges[0]);
			lengths[1] = length(edges[1]);
			lengths[2] = length(edges[2]);

			// Compute the cos angle of each vertices
			float cosAngles[3];
			cosAngles[0] = dot(-edges[2], edges[0]) / (lengths[2] * lengths[0]);
			cosAngles[1] = dot(-edges[0], edges[1]) / (lengths[0] * lengths[1]);
			cosAngles[2] = dot(-edges[1], edges[2]) / (lengths[1] * lengths[2]);

			// The height for each vertices of the triangle
			float heights[3];
			heights[1] = lengths[0] * sqrt(1 - cosAngles[0] * cosAngles[0]);
			heights[2] = lengths[1] * sqrt(1 - cosAngles[1] * cosAngles[1]);
			heights[0] = lengths[2] * sqrt(1 - cosAngles[2] * cosAngles[2]);

			float edgeSigns[3];
			edgeSigns[0] = (edges[0].x > 0 ? 1 : -1);
			edgeSigns[1] = (edges[1].x > 0 ? 1 : -1);
			edgeSigns[2] = (edges[2].x > 0 ? 1 : -1);

			float edgeOffsets[3];
			edgeOffsets[0] = lengths[0] * (0.5 - 0.5*edgeSigns[0]);
			edgeOffsets[1] = lengths[1] * (0.5 - 0.5*edgeSigns[1]);
			edgeOffsets[2] = lengths[2] * (0.5 - 0.5*edgeSigns[2]);

			output.Pos = (input[0].Pos);
			output.EdgeA[0] = 0;
			output.EdgeA[1] = heights[0];
			output.EdgeA[2] = 0;
			output.EdgeB[0] = edgeOffsets[0];
			output.EdgeB[1] = edgeOffsets[1] + edgeSigns[1] * cosAngles[1] * lengths[0];
			output.EdgeB[2] = edgeOffsets[2] + edgeSigns[2] * lengths[2];
			output.Col = float4(input[0].Pos.z, 0, 0, 1);
			outStream.Append(output);

			output.Pos = (input[1].Pos);
			output.EdgeA[0] = 0;
			output.EdgeA[1] = 0;
			output.EdgeA[2] = heights[1];
			output.EdgeB[0] = edgeOffsets[0] + edgeSigns[0] * lengths[0];
			output.EdgeB[1] = edgeOffsets[1];
			output.EdgeB[2] = edgeOffsets[2] + edgeSigns[2] * cosAngles[2] * lengths[1];
			output.Col = float4(input[0].Pos.z, 0, 0, 1);
			outStream.Append(output);

			output.Pos = (input[2].Pos);
			output.EdgeA[0] = heights[2];
			output.EdgeA[1] = 0;
			output.EdgeA[2] = 0;
			output.EdgeB[0] = edgeOffsets[0] + edgeSigns[0] * cosAngles[0] * lengths[2];
			output.EdgeB[1] = edgeOffsets[1] + edgeSigns[1] * lengths[1];
			output.EdgeB[2] = edgeOffsets[2];
			output.Col = float4(input[0].Pos.z, 0, 0, 1);
			outStream.Append(output);

		}
		// Else need some tricky computations
		else
		{
			// Then compute and pass the edge definitions from the case
			output.EdgeA.xy = points[infoA[output.Case]];
			output.EdgeB.xy = points[infoB[output.Case]];

			output.EdgeA.zw = normalize(output.EdgeA.xy - points[infoAd[output.Case]]);
			output.EdgeB.zw = normalize(output.EdgeB.xy - points[infoBd[output.Case]]);

			// Generate vertices
			output.Pos = (input[0].Pos);
			outStream.Append(output);

			output.Pos = (input[1].Pos);
			outStream.Append(output);

			output.Pos = (input[2].Pos);
			outStream.Append(output);

		}

	}



	float evalMinDistanceToSelectEdges(in PS_INPUT_WIRE input, float3 EdgesToUse)
	{
		float dist;

		// The easy case, the 3 distances of the fragment to the 3 edges is already
		// computed, get the min.
		if (input.Case == 0)
		{
			input.EdgeA.xyz += EdgesToUse * FLT_MAX;
			dist = min(min(input.EdgeA.x, input.EdgeA.y), input.EdgeA.z);
		}
		// The tricky case, compute the distances and get the min from the 2D lines
		// given from the geometry shader.
		else
		{
			// Compute and compare the sqDist, do one sqrt in the end.

			float2 AF = input.Pos.xy - input.EdgeA.xy;
			float sqAF = dot(AF, AF);
			float AFcosA = dot(AF, input.EdgeA.zw);

			int lineSegmentNumber = lineNum[(infoA[input.Case] + infoAd[input.Case] - 1)];

			dist = abs(sqAF - AFcosA*AFcosA) + (EdgesToUse[lineSegmentNumber])* FLT_MAX;

			float2 BF = input.Pos.xy - input.EdgeB.xy;
			float sqBF = dot(BF, BF);
			float BFcosB = dot(BF, input.EdgeB.zw);

			lineSegmentNumber = lineNum[(infoB[input.Case] + infoBd[input.Case] - 1)];
			dist = min(dist, abs(sqBF - BFcosB*BFcosB) + (EdgesToUse[lineSegmentNumber]) * FLT_MAX);

			// Only need to care about the 3rd edge for some cases.
			if (input.Case == 1 || input.Case == 2 || input.Case == 4)
			{
				float AFcosA0 = dot(AF, normalize(input.EdgeB.xy - input.EdgeA.xy));
				lineSegmentNumber = lineNum[(infoA[input.Case] + infoB[input.Case] - 1)];
				dist = min(dist, abs(sqAF - AFcosA0*AFcosA0) +EdgesToUse[lineSegmentNumber] * FLT_MAX);
			}

			dist = sqrt(dist);
		}

		return dist;
	}



	float4 PS_WIREFRAME_SELECT_EDGES(PS_INPUT_WIRE input) : SV_Target
	{
		// Compute the shortest square distance between the fragment and the edges.
		float dist = evalMinDistanceToSelectEdges(input, _EdgesToDraw.xyz);

	// Cull fragments too far from the edge.
	if (dist > 0.5*_LineWidth + 1) discard;

	// Map the computed distance to the [0,2] range on the border of the line.
	dist = clamp((dist - (0.5*_LineWidth - 1)), 0, 2);

	// Alpha is computed from the function exp2(-2(x)^2).
	dist *= dist;
	float alpha = exp2(-2 * dist);

	// Standard wire color but faded by distance
	// Dividing by pos.w, the depth in view space
	float fading = clamp(_FadeDistance / input.Pos.w, 0, 1);

	float4 color = _LineColor * fading;
	color.a *= alpha;
	return color;
	}




	ENDCG


	SubShader{

		Pass
		{
			Blend SrcAlpha OneMinusSrcAlpha
			CGPROGRAM
			#pragma vertex VS
			#pragma geometry GS_SOLID_WIRE
			#pragma fragment PS_WIREFRAME_SELECT_EDGES
			ENDCG
		}
	}
}
