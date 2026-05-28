Shader "Custom/BlinnPhong/BlueWillowBP"
{
    Properties
    {
        // ── Iluminación ───────────────────────────────────────────────
        _AmbientLight   ("Ambient Light",        Color)  = (1,1,1,1)
        _MaterialKa     ("Material Ka",          Vector) = (0.35,0.35,0.35,0)
        _MaterialKs     ("Material Ks",          Vector) = (0.08,0.08,0.14,0)
        _Material_n     ("Material n (brillo)",  Float)  = 32.0

        // ── Paleta ────────────────────────────────────────────────────
        _ColorBase      ("Porcelana base",       Color)  = (0.96, 0.96, 0.98, 1)
        _ColorDark      ("Azul oscuro",          Color)  = (0.10, 0.23, 0.54, 1)
        _ColorMid       ("Azul medio",           Color)  = (0.18, 0.40, 0.76, 1)
        _ColorLight     ("Azul claro",           Color)  = (0.45, 0.65, 0.90, 1)

        // ── Layout ────────────────────────────────────────────────────
        _GridCount      ("Flores por fila",      Range(1,30))      = 8
        _PeonyRadius    ("Radio peonía",         Range(0.05,3)) = 0.13
        _SmallRadius    ("Radio flor pequeña",   Range(0.02,3)) = 0.045
        _SmallOffset    ("Offset flor pequeña",  Range(0.0, 1.0))  = 0.4
        _Jitter         ("Jitter de posición",   Range(0,4))       = 0.08

        // ── Bandas ────────────────────────────────────────────────────
        _BandTopY       ("Banda superior Y",     Range(0, 1.0))    = 0.15
        _BandTopH       ("Banda superior Alto",  Range(0.01, 0.5)) = 0.08
        _BandBotY       ("Banda inferior Y",     Range(0, 1.0))    = 0.75
        _BandBotH       ("Banda inferior Alto",  Range(0.01, 0.5)) = 0.25
    }

    SubShader
    {
        Tags { "RenderType"="Opaque" }
        Pass
        {
            CGPROGRAM
            #pragma vertex   vertexShader
            #pragma fragment fragmentShader
            #include "UnityCG.cginc"
            #include "../LightingGlobals.cginc"

            float4 _AmbientLight, _MaterialKa, _MaterialKs;
            float  _Material_n;

            struct vertexData { float4 position:POSITION; float3 normal:NORMAL; float2 uv:TEXCOORD0; };
            struct v2f {
                float4 position   :SV_POSITION;
                float4 position_w :TEXCOORD0;
                float3 normal_w   :TEXCOORD1;
                float2 uv         :TEXCOORD2;
            };

            #include "../BlueWillowPattern.cginc" // Importamos patrón y funciones matematicas

            // ════════════════════════════════════════════════════════
            //  VERTEX / FRAGMENT
            // ════════════════════════════════════════════════════════
            v2f vertexShader(vertexData v)
            {
                v2f o;
                o.position   = UnityObjectToClipPos(v.position);
                o.position_w = mul(unity_ObjectToWorld, v.position);
                o.normal_w   = UnityObjectToWorldNormal(v.normal);
                o.uv         = v.uv;
                return o;
            }

            fixed4 fragmentShader(v2f f) : SV_Target
            {
                float3 col = getBlueWillowPattern(f.uv);

                float3 N = normalize(f.normal_w);
                float3 V = normalize(_WorldSpaceCameraPos - f.position_w.xyz);
                float3 totalDiffuse = 0, totalSpecular = 0;
                float3 L, lightColor;
                LightResult r;

                GetDirLight(L, lightColor);
                r = BlinnPhongLight(N, V, L, lightColor, col, _MaterialKs.rgb, _Material_n);
                totalDiffuse += r.diffuse; totalSpecular += r.specular;

                GetPointLight(f.position_w.xyz, L, lightColor);
                r = BlinnPhongLight(N, V, L, lightColor, col, _MaterialKs.rgb, _Material_n);
                totalDiffuse += r.diffuse; totalSpecular += r.specular;

                GetSpotLight(f.position_w.xyz, L, lightColor);
                r = BlinnPhongLight(N, V, L, lightColor, col, _MaterialKs.rgb, _Material_n);
                totalDiffuse += r.diffuse; totalSpecular += r.specular;

                float3 ambient = _MaterialKa.rgb * _AmbientLight.rgb * col;
                fixed4 fragColor;
                fragColor.rgb = ambient + totalDiffuse + totalSpecular;
                fragColor.a   = 1.0;
                return fragColor;
            }
            ENDCG
        }
    }
}
