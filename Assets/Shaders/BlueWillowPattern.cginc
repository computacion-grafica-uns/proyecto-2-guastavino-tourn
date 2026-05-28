#ifndef BLUE_WILLOW_PATTERN_INCLUDED
#define BLUE_WILLOW_PATTERN_INCLUDED

float4 _ColorBase, _ColorDark, _ColorMid, _ColorLight;
float  _GridCount, _PeonyRadius, _SmallRadius, _SmallOffset, _Jitter;
float  _BandTopY, _BandTopH, _BandBotY, _BandBotH;

// ════════════════════════════════════════════════════════
//  HASH & NOISE — sin loops costosos
// ════════════════════════════════════════════════════════
float hash21(float2 p)
{
    return frac(sin(dot(p, float2(127.1, 311.7))) * 43758.5453);
}
float2 hash22(float2 p)
{
    p = float2(dot(p, float2(127.1, 311.7)),
               dot(p, float2(269.5, 183.3)));
    return frac(sin(p) * 43758.5453);
}

// noise de valor — 1 sola octava (barato)
float vNoise(float2 uv)
{
    float2 i = floor(uv), f = frac(uv);
    float2 u = f * f * (3.0 - 2.0 * f);
    float a = hash21(i), b = hash21(i + float2(1,0));
    float c = hash21(i + float2(0,1)), d = hash21(i + float2(1,1));
    return lerp(lerp(a,b,u.x), lerp(c,d,u.x), u.y);
}

// smoothstep compacto
float ss(float a, float b, float x)
{
    float t = saturate((x - a) / (b - a));
    return t * t * (3.0 - 2.0 * t);
}

// Versión más robusta: distancia al borde de la elipse
float sdEllipseRobust(float2 p, float ax, float ay)
{
    float2 pa = abs(p);
    float t = UNITY_PI * 0.25;
    for(int it = 0; it < 4; it++)
    {
        float ct = cos(t), st = sin(t);
        float2 e  = float2(ax * ct, ay * st);
        float2 de = float2(-ax * st, ay * ct); 
        float2 r  = pa - e;
        float f   = dot(r, de);                
        float df  = dot(de, de) - dot(r, float2(-ax*ct, -ay*st)); 
        t -= f / (df + 1e-6);
        t  = clamp(t, 0.0, UNITY_PI * 0.5);
    }
    float2 nearest = float2(ax * cos(t), ay * sin(t));
    float dist = length(pa - nearest);
    float inside = (pa.x * pa.x) / (ax * ax) + (pa.y * pa.y) / (ay * ay);
    return dist * (inside < 1.0 ? -1.0 : 1.0);
}

// ════════════════════════════════════════════════════════
//  PÉTALO — elipse orientada radialmente
// ════════════════════════════════════════════════════════
float petalSDF(float2 lp, float ang, float rMid, float hLen, float hWid)
{
    float ca = cos(ang), sa = sin(ang);
    float2 ctr = float2(ca, sa) * rMid;
    float2 d   = lp - ctr;
    float2 ld  = float2( ca * d.x + sa * d.y,
                        -sa * d.x + ca * d.y);
    return sdEllipseRobust(ld, hLen, hWid);
}

// ════════════════════════════════════════════════════════
//  PEONÍA — 4 anillos de pétalos + pistilo + stamens
// ════════════════════════════════════════════════════════
float4 peonyColor(float2 lp, float seed, float R)
{
    float rot = hash21(float2(seed, 0.1)) * UNITY_TWO_PI;
    float ca0 = cos(rot), sa0 = sin(rot);
    float2 rp = float2(ca0 * lp.x - sa0 * lp.y,
                       sa0 * lp.x + ca0 * lp.y);

    float layers[5*4];  
    layers[ 0]=8; layers[ 1]=R*0.72; layers[ 2]=R*0.30; layers[ 3]=R*0.14; layers[ 4]=0.0;
    layers[ 5]=8; layers[ 6]=R*0.52; layers[ 7]=R*0.25; layers[ 8]=R*0.11; layers[ 9]=UNITY_PI/8.0;
    layers[10]=6; layers[11]=R*0.34; layers[12]=R*0.20; layers[13]=R*0.10; layers[14]=UNITY_PI/6.0;
    layers[15]=5; layers[16]=R*0.18; layers[17]=R*0.14; layers[18]=R*0.08; layers[19]=UNITY_PI/5.0;

    float maskOuter=0, maskMid=0, maskInner=0;

    {
        int n=int(layers[0]);
        float angStep = UNITY_TWO_PI / float(n);
        float off = layers[4];
        for(int i=0;i<8;i++){
            if(i>=n) break;
            float a = float(i)*angStep + off;
            float d = petalSDF(rp, a, layers[1], layers[2], layers[3]);
            maskOuter = max(maskOuter, 1.0 - ss(-0.004, 0.008, d));
        }
    }
    {
        int n=int(layers[5]);
        float angStep = UNITY_TWO_PI / float(n);
        float off = layers[9];
        for(int i=0;i<8;i++){
            if(i>=n) break;
            float a = float(i)*angStep + off;
            float d = petalSDF(rp, a, layers[6], layers[7], layers[8]);
            maskMid = max(maskMid, 1.0 - ss(-0.003, 0.007, d));
        }
    }
    {
        int n=int(layers[10]);
        float angStep = UNITY_TWO_PI / float(n);
        float off = layers[14];
        for(int i=0;i<6;i++){
            if(i>=n) break;
            float a = float(i)*angStep + off;
            float d = petalSDF(rp, a, layers[11], layers[12], layers[13]);
            maskMid = max(maskMid, 1.0 - ss(-0.003, 0.006, d));
        }
    }
    {
        int n=int(layers[15]);
        float angStep = UNITY_TWO_PI / float(n);
        float off = layers[19];
        for(int i=0;i<5;i++){
            if(i>=n) break;
            float a = float(i)*angStep + off;
            float d = petalSDF(rp, a, layers[16], layers[17], layers[18]);
            maskInner = max(maskInner, 1.0 - ss(-0.002, 0.005, d));
        }
    }

    float dCenter = length(rp);
    float pistilDisc  = 1.0 - ss(0.0,    R*0.06, dCenter);  

    float stamens = 0;
    for(int s=0;s<8;s++){
        float sa2 = float(s) / 8.0 * UNITY_TWO_PI;
        float2 sp = rp - float2(cos(sa2), sin(sa2)) * R * 0.13;
        stamens = max(stamens, 1.0 - ss(0.0, R*0.028, length(sp)));
    }

    float totalMask = saturate(maskOuter + maskMid + maskInner + pistilDisc + stamens);

    float3 col = _ColorLight.rgb;                           
    col = lerp(col, _ColorMid.rgb,  maskMid);              
    col = lerp(col, _ColorDark.rgb, maskInner);            
    col = lerp(col, _ColorDark.rgb, pistilDisc);           
    col = lerp(col, _ColorLight.rgb, stamens * 0.6);       

    float veinAngle = atan2(rp.y, rp.x) * 8.0;
    float vein = smoothstep(0.55, 0.75, sin(veinAngle) * 0.5 + 0.5);
    col = lerp(col, _ColorLight.rgb, vein * maskOuter * 0.30);

    return float4(col, totalMask);
}

// ════════════════════════════════════════════════════════
//  FLOR PEQUEÑA
// ════════════════════════════════════════════════════════
float4 smallFlowerColor(float2 lp, float seed, float R)
{
    float rot = hash21(float2(seed, 0.7)) * UNITY_TWO_PI;
    float angStep = UNITY_TWO_PI / 8.0;
    float mask = 0;

    for(int i=0;i<8;i++){
        float a = float(i) * angStep + rot;
        float d = petalSDF(lp, a, R * 0.55, R * 0.52, R * 0.18);
        mask = max(mask, 1.0 - ss(-0.003, 0.007, d));
    }
    float dC = length(lp);
    float centre = 1.0 - ss(0.0, R * 0.22, dC);
    mask = max(mask, centre);

    float3 col = lerp(_ColorMid.rgb, _ColorDark.rgb, centre);
    return float4(col, mask);
}

// ════════════════════════════════════════════════════════
//  GRID DE FLORES
// ════════════════════════════════════════════════════════
float3 flowerGrid(float2 uv)
{
    float3 col = _ColorBase.rgb;

    float noise = vNoise(uv * 60.0) * 0.018;
    col += noise;

    float2 cellUV  = uv * _GridCount;
    float2 cellID  = floor(cellUV);
    float2 localUV = frac(cellUV);          

    for(int dy = -1; dy <= 1; dy++)
    for(int dx = -1; dx <= 1; dx++)
    {
        float2 nID  = cellID + float2(dx, dy);
        float2 seed2 = hash22(nID);

        float2 peonyCenter = float2(0.5, 0.5) + (seed2 - 0.5) * _Jitter * 2.0;
        float2 lp = localUV - (peonyCenter + float2(dx, dy));

        float4 peo = peonyColor(lp, hash21(nID), _PeonyRadius);
        if(peo.a > 0.01)
            col = lerp(col, peo.rgb, peo.a);

        float2 seed3   = hash22(nID + float2(7.3, 4.1));
        
        float2 offset = seed3 - 0.5;
        float2 smCenter = peonyCenter + normalize(offset) * (_SmallOffset + length(offset) * 0.6);
        float2 lp2 = localUV - (smCenter + float2(dx, dy));
        float4 sm = smallFlowerColor(lp2, hash21(nID + 5.0), _SmallRadius);
        if(sm.a > 0.01)
            col = lerp(col, sm.rgb, sm.a);
    }

    return saturate(col);
}

// ════════════════════════════════════════════════════════
//  BANDAS DECORATIVAS
// ════════════════════════════════════════════════════════
float3 applyBands(float3 col, float2 uv)
{
    float y = uv.y;

    float topH = _BandTopH;
    float botH = _BandBotH;
    float lineW = 0.003; 
    
    // Ocultamos las líneas de la banda superior
    // float l0 = 1.0 - step(lineW, abs(y - _BandTopY));
    // float l1 = 1.0 - step(lineW, abs(y - (_BandTopY + topH)));
    float l2 = 1.0 - step(lineW, abs(y - _BandBotY));
    float l3 = 1.0 - step(lineW, abs(y - (_BandBotY + botH)));
    float lines = saturate(l2 + l3);
    col = lerp(col, _ColorDark.rgb, lines);

    /*
    // ── Banda superior: Líneas paralelas y cuadrados ──
    float mCenterY = _BandTopY + (topH * 0.5);
    float mHalf    = topH * 0.5;
    float distMY   = abs(y - mCenterY);
    if(distMY < mHalf)
    {
        float stepX = topH * 1.5; 
        float cx = frac(uv.x / stepX) * stepX - (stepX * 0.5);
        float cy = y - mCenterY;
        
        float pat = 0;
        
        // Líneas horizontales top & bottom
        float lineDist = abs(abs(cy) - (topH * 0.35));
        float innerLineW = topH * 0.06; 
        pat = max(pat, 1.0 - step(innerLineW, lineDist));
        
        // Cuadrados perfectos centrales
        float sqSize = topH * 0.15; 
        float sqMask = 1.0 - step(sqSize, max(abs(cx), abs(cy)));
        pat = max(pat, sqMask);
        
        col = lerp(col, _ColorMid.rgb, saturate(pat));
    }
    */

    // ── Banda inferior: paneles rectangulares ─────────
    float pTop = _BandBotY;
    float pBot = _BandBotY + botH;
    if(y > pTop && y < pBot)
    {
        float stepX = botH * 1; 
        float xf   = frac(uv.x / stepX);
        float yn   = (y - pTop) / botH;
        float mg   = 0.07;
        
        float frameX = 1.0 - step(mg, min(xf, 1.0 - xf));
        float frameY = 1.0 - step(0.06, min(yn, 1.0 - yn));
        float frame  = max(frameX, frameY);
        
        float cx2 = xf - 0.5, cy2 = yn - 0.5;
        float diam  = 1.0 - step(0.26, abs(cx2) + abs(cy2));
        float cen   = 1.0 - step(0.07, length(float2(cx2, cy2)));
        col = lerp(col, _ColorMid.rgb, saturate(frame * 0.9 + diam * 0.7 + cen));
    }

    return col;
}

// Wrapper final
float3 getBlueWillowPattern(float2 uv)
{
    float3 col = flowerGrid(uv);
    return applyBands(col, uv);
}

#endif
