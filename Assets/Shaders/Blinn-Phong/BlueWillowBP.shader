Shader "Custom/BlueWillowBP"
{
    Properties
    {
        // ── Iluminación ───────────────────────────────────────────────
        _AmbientLight    ("Ambient Light",           Color)      = (1,1,1,1)
        _MaterialKa      ("Material Ka",             Vector)     = (0.35,0.35,0.35,0)
        _MaterialKs      ("Material Ks",             Vector)     = (0.08,0.08,0.14,0)
        _Material_n      ("Material n (brillo)",     Float)      = 32.0

        // ── Paleta ────────────────────────────────────────────────────
        _ColorBase       ("Porcelana base",          Color)      = (0.96, 0.96, 0.98, 1)
        _ColorDark       ("Azul oscuro",             Color)      = (0.10, 0.23, 0.54, 1)
        _ColorMid        ("Azul medio",              Color)      = (0.14, 0.34, 0.72, 1)
        _ColorLight      ("Azul claro",              Color)      = (0.29, 0.50, 0.83, 1)
        _ColorHighlight  ("Azul muy claro",          Color)      = (0.54, 0.71, 0.91, 1)

        // ── Control de patrón ─────────────────────────────────────────
        _PatternScale    ("Repeticiones en UV",      Float)      = 1.0
        _PeonyScale      ("Tamaño peonías",          Range(0.03,0.18)) = 0.10
        _ScrollDensity   ("Densidad de volutas",     Range(0,1)) = 0.7
        _BandTop         ("Banda superior Y",        Range(0,0.2)) = 0.10
        _BandMid         ("Banda media Y",           Range(0.3,0.6)) = 0.38
        _BandBottom      ("Banda inferior Y",        Range(0.7,1.0)) = 0.85
        _BandThickness   ("Grosor de banda",         Range(0.005,0.05)) = 0.025
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
            float4 _ColorBase, _ColorDark, _ColorMid, _ColorLight, _ColorHighlight;
            float  _PatternScale, _PeonyScale, _ScrollDensity;
            float  _BandTop, _BandMid, _BandBottom, _BandThickness;

            struct vertexData { float4 position:POSITION; float3 normal:NORMAL; float2 uv:TEXCOORD0; };
            struct v2f {
                float4 position  :SV_POSITION;
                float4 position_w:TEXCOORD0;
                float3 normal_w  :TEXCOORD1;
                float2 uv        :TEXCOORD2;
            };

            // ════════════════════════════════════════════════════════════
            //  UTILIDADES
            // ════════════════════════════════════════════════════════════
            float hash11(float n){return frac(sin(n)*43758.5453);}
            float hash21(float2 p){return frac(sin(dot(p,float2(127.1,311.7)))*43758.5453);}
            float2 hash22(float2 p){
                p=float2(dot(p,float2(127.1,311.7)),dot(p,float2(269.5,183.3)));
                return frac(sin(p)*43758.5453);
            }
            float clamp01(float v){return saturate(v);}
            float ss(float a,float b,float x){float t=clamp01((x-a)/(b-a));return t*t*(3-2*t);}

            // noise de valor
            float vNoise(float2 uv){
                float2 i=floor(uv),f=frac(uv);
                float2 u=f*f*(3-2*f);
                float a=hash21(i),b=hash21(i+float2(1,0));
                float c2=hash21(i+float2(0,1)),d=hash21(i+float2(1,1));
                return lerp(lerp(a,b,u.x),lerp(c2,d,u.x),u.y);
            }
            float fbm2(float2 uv){
                float v=0,a=0.5;
                for(int o=0;o<3;o++){v+=a*vNoise(uv);uv*=2.1;a*=0.5;}
                return v;
            }

            // ════════════════════════════════════════════════════════════
            //  SDF helpers
            // ════════════════════════════════════════════════════════════
            float sdEllipse(float2 p,float2 ab){
                // aproximación eficiente
                float k1=length(p/ab);
                return (k1-1.0)*min(ab.x,ab.y);
            }
            float sdSegment(float2 p,float2 a,float2 b){
                float2 pa=p-a,ba=b-a;
                float h=clamp01(dot(pa,ba)/dot(ba,ba));
                return length(pa-ba*h);
            }

            // ════════════════════════════════════════════════════════════
            //  FLOR DE PEONÍA
            //  Retorna [0,1]: 0=fondo, valores altos=pétalos/centro
            // ════════════════════════════════════════════════════════════
            float peonyLayer(float2 lp, int nPetals, float rInner, float rOuter, float rotOff)
            {
                float result=0;
                float angStep=UNITY_TWO_PI/float(nPetals);
                for(int i=0;i<nPetals;i++){
                    float a=float(i)*angStep+rotOff;
                    float ca=cos(a),sa=sin(a);
                    // centro del pétalo
                    float r=(rInner+rOuter)*0.5;
                    float2 pc=float2(ca,sa)*r;
                    // pétalo = elipse estirada en dirección radial
                    float2 d=lp-pc;
                    // rotar d al sistema local del pétalo
                    float2 ld=float2(dot(d,float2(ca,sa)), dot(d,float2(-sa,ca)));
                    float hw=(rOuter-rInner)*0.5*1.1;
                    float hr=rOuter*0.28;
                    float e=sdEllipse(ld,float2(hw,hr));
                    result=max(result,1-ss(-0.005,0.012,e));
                }
                return result;
            }

            float peonyMask(float2 lp, float seed)
            {
                // rotar toda la flor con la seed
                float rot=hash11(seed)*UNITY_TWO_PI;
                float ca=cos(rot),sa=sin(rot);
                float2 rp=float2(ca*lp.x-sa*lp.y, sa*lp.x+ca*lp.y);

                float r=_PeonyScale;
                // 4 capas de pétalos
                float l0=peonyLayer(rp, 8, r*0.72, r*1.0,  rot*0.3);
                float l1=peonyLayer(rp, 8, r*0.50, r*0.75, rot*0.7);
                float l2=peonyLayer(rp, 6, r*0.30, r*0.55, rot*1.1);
                float l3=peonyLayer(rp, 5, r*0.14, r*0.32, rot*1.5);
                // pistilo
                float pistil=1-ss(0,r*0.1,length(rp));
                // venas: rayas radiales sobre cada capa
                float veinAngle=atan2(rp.y,rp.x)*8.0+length(rp)*60;
                float veins=smoothstep(0.3,0.7,sin(veinAngle)*0.5+0.5);

                float shape=saturate(l0*0.55+l1*0.7+l2*0.85+l3*1.0+pistil);
                return saturate(shape + veins*l0*0.2);
            }

            // tono dentro de la peonía (más oscuro en capas internas)
            float peonyTone(float2 lp)
            {
                float d=length(lp)/_PeonyScale;
                return clamp01(d);  // 0=centro oscuro, 1=borde claro
            }

            // ════════════════════════════════════════════════════════════
            //  FLORES PEQUEÑAS (crisantemo)
            // ════════════════════════════════════════════════════════════
            float smallFlower(float2 lp, float r, float seed)
            {
                float result=0;
                float rot=hash11(seed+0.3)*UNITY_TWO_PI;
                for(int i=0;i<12;i++){
                    float a=float(i)/12.0*UNITY_TWO_PI+rot;
                    float2 dir=float2(cos(a),sin(a));
                    float2 pc=dir*r*0.65;
                    // pétalo elíptico orientado radialmente
                    float2 d=lp-pc;
                    float2 ld=float2(dot(d,dir),dot(d,float2(-dir.y,dir.x)));
                    float e=sdEllipse(ld,float2(r*0.42,r*0.22));
                    result=max(result,1-ss(-0.003,0.008,e));
                }
                // centro
                result=max(result,1-ss(0,r*0.25,length(lp)));
                return result;
            }

            // ════════════════════════════════════════════════════════════
            //  RED DE VOLUTAS
            //  Bezier cúbica implícita subdividida en segmentos
            // ════════════════════════════════════════════════════════════
            float bezierDist(float2 uv, float2 p0,float2 p1,float2 p2,float2 p3)
            {
                float minD=1e9;
                float2 prev=p0;
                for(int k=1;k<=20;k++){
                    float t=float(k)/20.0, mt=1-t;
                    float2 cur= mt*mt*mt*p0
                               +3*mt*mt*t*p1
                               +3*mt*t*t*p2
                                 +t*t*t*p3;
                    minD=min(minD,sdSegment(uv,prev,cur));
                    prev=cur;
                }
                return minD;
            }

            // Una voluta en S con dos curvas
            float scrollMask(float2 uv, float2 origin, float sc, float flip, float seed)
            {
                float f=flip>0.5?-1:1;
                // transformar al sistema local
                float2 p=(uv-origin)/sc;
                p.y*=f;

                float2 p0=float2(0,0);
                float2 p1=float2(0.30,-0.10);
                float2 p2=float2(0.60,-0.40);
                float2 p3=float2(0.50,-0.65);

                float2 q0=p3;
                float2 q1=float2(0.10,-0.85);
                float2 q2=float2(-0.08,-0.70);
                float2 q3=float2(0.08,-0.60);

                float d1=bezierDist(p,p0,p1,p2,p3);
                float d2=bezierDist(p,q0,q1,q2,q3);
                float d=min(d1,d2);

                // rama lateral
                float2 b0=float2(0.25,-0.40);
                float2 b1=float2(0.45,-0.35);
                float2 b2=float2(0.55,-0.18);
                float2 b3=float2(0.50,-0.05);
                float db=bezierDist(p,b0,b1,b2,b3);
                d=min(d,db);

                float thickness=0.04;
                return 1-ss(thickness*0.4,thickness,d);
            }

            // hoja (elipse rotada)
            float leafMask(float2 uv, float2 center, float ang, float sc)
            {
                float2 d=uv-center;
                float ca=cos(ang),sa=sin(ang);
                float2 ld=float2(ca*d.x+sa*d.y,-sa*d.x+ca*d.y);
                float e=sdEllipse(ld,float2(sc*0.12,sc*0.05));
                float shape=1-ss(-0.003,0.010,e);
                // nervio
                float vein=shape*(1-ss(0,sc*0.015,abs(ld.x)));
                return saturate(shape*0.8+vein*0.3);
            }

            // capullo (elipse estrecha + sépalos)
            float budMask(float2 uv, float2 center, float ang, float sc)
            {
                float2 d=uv-center;
                float ca=cos(ang),sa=sin(ang);
                float2 ld=float2(ca*d.x+sa*d.y,-sa*d.x+ca*d.y);
                float body=sdEllipse(ld,float2(sc*0.07,sc*0.13));
                float shape=1-ss(-0.002,0.009,body);
                // sépalos
                float sep1=sdSegment(uv,center,center+float2(cos(ang+0.6),sin(ang+0.6))*sc*0.16);
                float sep2=sdSegment(uv,center,center+float2(cos(ang-0.6),sin(ang-0.6))*sc*0.16);
                shape=max(shape,max(1-ss(0.004,0.010,sep1),1-ss(0.004,0.010,sep2)));
                return shape;
            }

            // ════════════════════════════════════════════════════════════
            //  BANDAS DECORATIVAS
            // ════════════════════════════════════════════════════════════

            // greca de meandros (greek key)
            float meanderBand(float2 uv, float centerY, float halfH)
            {
                float distY=abs(uv.y-centerY);
                if(distY>halfH) return 0;
                float mask=1-ss(halfH*0.85,halfH,distY);
                // patrón repetido en X
                float step=0.05;
                float xf=frac(uv.x/step);
                float xstep=floor(uv.x/step);
                float ynorm=(uv.y-centerY)/halfH; // [-1,1]
                // meandro: cuadrado compuesto de segmentos
                float pat=0;
                // línea top
                pat=max(pat,(xf<0.9?1:0)*ss(0.75,0.85,ynorm));
                // línea bottom
                pat=max(pat,(xf>0.1?1:0)*ss(-0.85,-0.75,-ynorm));
                // lado derecho (subida)
                pat=max(pat,(xf>0.8&&xf<0.95)?ss(-0.2,0.1,ynorm):0);
                // interior horizontal medio
                pat=max(pat,(xf<0.55&&fmod(xstep,2)<1)?ss(0.0,0.15,ynorm)*ss(0.5,0.35,ynorm):0);
                return saturate(mask*pat*1.5);
            }

            // banda de rombos
            float diamondBand(float2 uv, float centerY, float halfH)
            {
                float distY=abs(uv.y-centerY);
                if(distY>halfH) return 0;
                float step=0.04;
                float2 q=float2(frac(uv.x/step)-0.5, (uv.y-centerY)/halfH);
                float d=abs(q.x)+abs(q.y)-0.55;
                float outer=1-ss(-0.05,0.02,d);
                float inner=1-ss(-0.15,0.02,d+0.25);
                // líneas de borde de banda
                float border=ss(0.80,0.92,abs(uv.y-centerY)/halfH);
                return saturate(outer-inner*0.5+border*1.2);
            }

            // panel rectangular inferior (plintos)
            float panelBand(float2 uv, float topY, float botY)
            {
                if(uv.y<topY||uv.y>botY) return 0;
                float step=0.10;
                float xf=frac(uv.x/step);
                float yn=(uv.y-topY)/(botY-topY);
                // marco del panel
                float margin=0.07;
                float frameX=(xf<margin||xf>1-margin)?1:0;
                float frameY=(yn<0.08||yn>0.92)?1:0;
                float frame=max(frameX,frameY);
                // diamante interior
                float cx2=xf-0.5;
                float cy2=yn-0.5;
                float diam=1-ss(0.0,0.04,abs(cx2)+abs(cy2)-0.25);
                float center=1-ss(0,0.04,length(float2(cx2,cy2))-0.06);
                return saturate(frame*0.9+diam*0.7+center);
            }

            // línea delgada
            float thinLine(float2 uv, float y, float halfW)
            {return 1-ss(halfW*0.5,halfW,abs(uv.y-y));}

            // ════════════════════════════════════════════════════════════
            //  CAMPO DE FLORES Y VOLUTAS
            // ════════════════════════════════════════════════════════════

            // posiciones fijas (relativas al tile) de peonías y elementos
            static const float2 peonyPos[5] = {
                float2(0.22,0.42), float2(0.65,0.52),
                float2(0.42,0.68), float2(0.80,0.28),
                float2(0.10,0.25)
            };
            static const float peonySeeds[5]={0.13,0.47,0.82,0.31,0.65};

            static const float2 smallPos[8]={
                float2(0.35,0.22),float2(0.55,0.32),float2(0.15,0.55),
                float2(0.75,0.68),float2(0.90,0.45),float2(0.05,0.72),
                float2(0.50,0.80),float2(0.28,0.78)
            };

            static const float2 scrollOrigin[6]={
                float2(0.10,0.30),float2(0.35,0.18),float2(0.60,0.40),
                float2(0.85,0.25),float2(0.25,0.62),float2(0.72,0.78)
            };
            static const float scrollFlip[6]={0,1,0,1,0,1};
            static const float scrollSc[6]={0.18,0.16,0.17,0.15,0.16,0.15};

            static const float2 leafPos[10]={
                float2(0.18,0.20),float2(0.40,0.28),float2(0.68,0.32),
                float2(0.78,0.58),float2(0.30,0.72),float2(0.55,0.65),
                float2(0.08,0.50),float2(0.92,0.62),float2(0.48,0.48),float2(0.62,0.20)
            };
            static const float leafAng[10]={0.5,1.2,-0.8,2.1,-1.5,0.9,-2.3,1.7,0.3,-1.1};

            static const float2 budPos[6]={
                float2(0.32,0.12),float2(0.70,0.15),float2(0.15,0.38),
                float2(0.88,0.72),float2(0.45,0.85),float2(0.05,0.80)
            };
            static const float budAng[6]={-0.4,0.6,-1.2,0.3,-0.7,1.0};

            // ════════════════════════════════════════════════════════════
            //  COMPOSICIÓN PRINCIPAL
            // ════════════════════════════════════════════════════════════
            float3 blueWillow(float2 uv)
            {
                // tile
                float2 tUV=frac(uv*_PatternScale);

                // ── fondo porcelana ──────────────────────────────────
                float pNoise=fbm2(uv*90)*0.025;
                float3 col=_ColorBase.rgb+pNoise;

                // ── volutas + hojas + capullos ───────────────────────
                float vines=0;
                for(int i=0;i<6;i++)
                    vines=max(vines,scrollMask(tUV,scrollOrigin[i],scrollSc[i],scrollFlip[i],float(i)));

                float leaves=0;
                for(int i=0;i<10;i++)
                    leaves=max(leaves,leafMask(tUV,leafPos[i],leafAng[i],1.0));

                float buds=0;
                for(int i=0;i<6;i++)
                    buds=max(buds,budMask(tUV,budPos[i],budAng[i],1.0));

                col=lerp(col,_ColorMid.rgb, vines *_ScrollDensity);
                col=lerp(col,_ColorMid.rgb, leaves*_ScrollDensity);
                col=lerp(col,_ColorDark.rgb,buds  *_ScrollDensity);

                // ── flores pequeñas ──────────────────────────────────
                for(int i=0;i<8;i++){
                    float2 lp=tUV-smallPos[i];
                    float sf=smallFlower(lp,0.055,float(i)*3.7);
                    float tone=length(lp)/0.055;
                    float3 fc=lerp(_ColorDark.rgb,_ColorLight.rgb,clamp01(tone*0.8));
                    col=lerp(col,fc,sf);
                }

                // ── peonías principales ──────────────────────────────
                for(int i=0;i<5;i++){
                    float2 lp=tUV-peonyPos[i];
                    float pm=peonyMask(lp,peonySeeds[i]);
                    float tone=peonyTone(lp);
                    // gradación de color: centro oscuro → borde medio → punta clara
                    float3 fc=lerp(_ColorDark.rgb,_ColorMid.rgb,tone*0.6);
                    fc=lerp(fc,_ColorLight.rgb,clamp01((tone-0.5)*2));
                    // venas claras
                    float veinPat=sin(atan2(lp.y,lp.x)*8+length(lp)*80)*0.5+0.5;
                    fc=lerp(fc,_ColorHighlight.rgb,veinPat*pm*0.35);
                    col=lerp(col,fc,pm);
                }

                // ── bandas decorativas ───────────────────────────────
                // líneas de separación
                col=lerp(col,_ColorDark.rgb, thinLine(tUV,_BandTop,             _BandThickness*0.3));
                col=lerp(col,_ColorDark.rgb, thinLine(tUV,_BandTop+_BandThickness*2, _BandThickness*0.3));
                col=lerp(col,_ColorDark.rgb, thinLine(tUV,_BandMid,             _BandThickness*0.3));
                col=lerp(col,_ColorDark.rgb, thinLine(tUV,_BandBottom,          _BandThickness*0.3));

                // greca superior
                float meander=meanderBand(tUV,_BandTop+_BandThickness,_BandThickness);
                col=lerp(col,_ColorMid.rgb,meander);

                // banda de rombos media
                float diamonds=diamondBand(tUV,_BandMid+_BandThickness,_BandThickness);
                col=lerp(col,_ColorDark.rgb,diamonds);

                // paneles inferiores
                float panels=panelBand(tUV,_BandBottom,1.0);
                col=lerp(col,_ColorMid.rgb,panels*0.9);

                return saturate(col);
            }

            // ════════════════════════════════════════════════════════════
            //  VERTEX / FRAGMENT
            // ════════════════════════════════════════════════════════════
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
                float3 patternColor = blueWillow(f.uv);

                float3 N = normalize(f.normal_w);
                float3 V = normalize(_WorldSpaceCameraPos - f.position_w.xyz);

                float3 totalDiffuse=0, totalSpecular=0;
                float3 L, lightColor;
                LightResult r;

                GetDirLight(L, lightColor);
                r=BlinnPhongLight(N,V,L,lightColor,patternColor,_MaterialKs.rgb,_Material_n);
                totalDiffuse+=r.diffuse; totalSpecular+=r.specular;

                GetPointLight(f.position_w.xyz, L, lightColor);
                r=BlinnPhongLight(N,V,L,lightColor,patternColor,_MaterialKs.rgb,_Material_n);
                totalDiffuse+=r.diffuse; totalSpecular+=r.specular;

                GetSpotLight(f.position_w.xyz, L, lightColor);
                r=BlinnPhongLight(N,V,L,lightColor,patternColor,_MaterialKs.rgb,_Material_n);
                totalDiffuse+=r.diffuse; totalSpecular+=r.specular;

                float3 ambient=_MaterialKa.rgb*_AmbientLight.rgb*patternColor;

                fixed4 fragColor;
                fragColor.rgb=ambient+totalDiffuse+totalSpecular;
                fragColor.a=1.0;
                return fragColor;
            }
            ENDCG
        }
    }
}
