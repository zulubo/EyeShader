Shader "Organic/Eye"
{
    Properties
    {
        _Color("Iris Color", Color) = (1,1,1,1)
        [NoScaleOffset] _MainTex("Main Texture", 2D) = "white" {}
        _BaseIrisSize("Iris Radius in texture", Float) = 0.4
        _BasePupilSize("Pupil Radius in texture", Float) = 0.1
        [NoScaleOffset] _NormalMap("Base Normal Map", 2D) = "bump" {}
        _NormalStrength("Base Normal Strength", Float) = 1.0
        [NoScaleOffset] _LensNormalMap("Lens Normal Map", 2D) = "bump" {}
        _LensNormalStrength("Lens Normal Strength", Float) = 1.0
        [NoScaleOffset] _Mask("Mask (R=Parallax, G=Iris", 2D) = "black" {}
        _Glossiness("Base Smoothness", Range(0,1)) = 0.4
        _LensGlossiness("Lens Smoothness", Range(0,1)) = 0.9
        [Toggle(PARALLAX)]
        _ParallaxToggle("Parallax Enabled", Float) = 0
        _Parallax("Lens Parallax", Float) = 0.1
        _IrisScale("Iris Scale", Float) = 1.0
        _PupilScale("Pupil Scale", Range(0, 1)) = 0.3
    }
        SubShader
        {

            // BASE PASS
            Tags { "RenderType" = "Opaque" }
            LOD 200

            CGPROGRAM
            #pragma surface surf Standard fullforwardshadows nolightmap
            #pragma shader_feature PARALLAX

            #pragma target 4.0

            struct Input {
                  float2 uv_MainTex;
#ifdef PARALLAX
                  float3 viewDir;
#endif
            };

            sampler2D _MainTex;
            sampler2D _NormalMap;
            sampler2D _Mask;

            half _BaseIrisSize;
            half _BasePupilSize;

            half _Glossiness;
            half _Parallax;
            half _NormalStrength;

            UNITY_INSTANCING_BUFFER_START(Props)
                UNITY_DEFINE_INSTANCED_PROP(fixed4, _Color)
                UNITY_DEFINE_INSTANCED_PROP(float, _IrisScale)
                UNITY_DEFINE_INSTANCED_PROP(float, _PupilScale)
            UNITY_INSTANCING_BUFFER_END(Props)

#ifdef PARALLAX

            #define PARALLAX_BIAS 0
            #define RAYMARCH_STEPS 8

            float GetParallaxHeight(float2 uv) {
                return tex2D(_Mask, uv).r * -_Parallax;
            }

            float2 ParallaxRaymarching(float2 uv, float2 viewDir)
            {
                float stepSize = 1.1 / RAYMARCH_STEPS;
                float2 uvOffset = 0;
                float2 uvDelta = -viewDir * (stepSize * _Parallax);
                float stepHeight = -0.001;
                float surfaceHeight = GetParallaxHeight(uv);

                float2 prevUVOffset = uvOffset;
                float prevStepHeight = 0;
                float prevSurfaceHeight = surfaceHeight;

                [unroll] for (int i = 1; i < RAYMARCH_STEPS && stepHeight > surfaceHeight; i++)
                {
                    prevUVOffset = uvOffset;
                    prevStepHeight = stepHeight;
                    prevSurfaceHeight = surfaceHeight;

                    uvOffset -= uvDelta;
                    stepHeight -= stepSize;
                    surfaceHeight = GetParallaxHeight(uv + uvOffset);
                }

                float prevDifference = prevStepHeight - prevSurfaceHeight;
                float difference = surfaceHeight - stepHeight;
                float t = prevDifference / (prevDifference + difference);
                uvOffset = lerp(prevUVOffset, uvOffset, t);

                return uvOffset;
            }
#endif

            float remap(float value, float a, float b, float a2, float b2)
            {
                return a2 + (value - a) * (b2 - a2) / (b - a);
            }

            void surf(Input IN, inout SurfaceOutputStandard o)
            {
                float2 uv = IN.uv_MainTex;
                float4 mask = tex2D(_Mask, uv);

                // scale iris
                uv -= 0.5;
                uv /= UNITY_ACCESS_INSTANCED_PROP(Props, _IrisScale);
                uv += 0.5;

#ifdef PARALLAX
                // apply iris parallax
                IN.viewDir.xy /= (-IN.viewDir.z + 0.1);
                uv += ParallaxRaymarching(uv, IN.viewDir);
#endif

                // apply pupil dilation
                uv -= 0.5;
                float r = length(uv) * 2;
                float scaledR = r;
                float pr = _BaseIrisSize * UNITY_ACCESS_INSTANCED_PROP(Props, _PupilScale);
                if (r < pr)
                {
                    scaledR = remap(r, 0, pr, 0, _BasePupilSize);
                }
                else if (r < _BaseIrisSize)
                {
                    scaledR = remap(r, pr, _BaseIrisSize, _BasePupilSize, _BaseIrisSize);
                }
                uv = uv / r * scaledR;
                uv += 0.5;


                float3 normal = UnpackNormal(tex2D(_NormalMap, uv));
                normal.xy *= _NormalStrength;

                // update mask with parallax
                mask = tex2D(_Mask, uv);

                fixed4 c = tex2D(_MainTex, uv) * lerp(1, UNITY_ACCESS_INSTANCED_PROP(Props, _Color), mask.g);
                o.Albedo = c.rgb;
                o.Normal = normal;
                o.Metallic = 0;
                o.Smoothness = _Glossiness;
                o.Alpha = 1;
                //o.Albedo = pmask > 0.01;
            }
            ENDCG


            //LENS PASS
            Blend One One
            ZWrite Off

            CGPROGRAM
            // Physically based Standard lighting model, and enable shadows on all light types
#pragma surface surf Standard fullforwardshadows nolightmap

#pragma target 4.0

        struct Input {
            float2 uv_MainTex;
        };
        sampler2D _LensNormalMap;
        sampler2D _Mask;
        half _LensGlossiness;
        half _IrisScale;
        half _LensNormalStrength;

        void surf(Input IN, inout SurfaceOutputStandard o)
        {
            float2 uv = IN.uv_MainTex;
            float3 mask = tex2D(_Mask, uv);

            // scale iris
            uv -= 0.5;
            uv /= _IrisScale;
            uv += 0.5;

            float3 normal = UnpackNormal(tex2D(_LensNormalMap, uv));
            normal.xy *= _LensNormalStrength;

            o.Albedo = 0;
            o.Normal = normal;
            o.Metallic = 0;
            o.Smoothness = _LensGlossiness;
            o.Alpha = 1;
        }
        ENDCG
    }
    FallBack "Diffuse"
}
