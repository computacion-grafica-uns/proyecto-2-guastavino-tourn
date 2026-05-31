using UnityEngine;
using System.Collections.Generic;

// ============================================================
//  MaterialManager.cs
//  Escanea todos los Renderers en Awake(), resuelve la config
//  final por tag (herencia jerárquica) y aplica un
//  MaterialPropertyBlock por renderer.
//
//  Sin instancias de material. Sin romper el batching.
//
//  _AlbedoMode se setea como int via SetInt en el PropertyBlock,
//  igual que cualquier otra propiedad numérica. Sin keywords,
//  sin tocar el material compartido.
// ============================================================

public class MaterialManager : MonoBehaviour
{
    [Header("Configuración")]
    [Tooltip("ScriptableObject con todos los nodos de la jerarquía de tags.")]
    public MaterialManagerConfig config;

    [Tooltip("Imprime en consola la config resuelta por cada tag único encontrado.")]
    public bool debugMode = false;

    // ── Property IDs (cache estático) ─────────────────────────
    private static readonly int ID_AmbientLight = Shader.PropertyToID("_AmbientLight");
    private static readonly int ID_Ka = Shader.PropertyToID("_MaterialKa");
    private static readonly int ID_Alpha = Shader.PropertyToID("_Alpha");

    private static readonly int ID_AlbedoMode = Shader.PropertyToID("_AlbedoMode");
    private static readonly int ID_BaseColor = Shader.PropertyToID("_BaseColor");
    private static readonly int ID_MainTex = Shader.PropertyToID("_MainTex");
    private static readonly int ID_MainTexST = Shader.PropertyToID("_MainTex_ST");

    private static readonly int ID_NormalMap = Shader.PropertyToID("_NormalMap");
    private static readonly int ID_NormalStrength = Shader.PropertyToID("_NormalStrength");

    private static readonly int ID_Kd = Shader.PropertyToID("_MaterialKd");
    private static readonly int ID_Ks = Shader.PropertyToID("_MaterialKs");
    private static readonly int ID_MaterialN = Shader.PropertyToID("_Material_n");

    private static readonly int ID_F0 = Shader.PropertyToID("_F0");
    private static readonly int ID_Roughness = Shader.PropertyToID("_Roughness");
    private static readonly int ID_DMethod = Shader.PropertyToID("_DMethod");
    private static readonly int ID_GMethod = Shader.PropertyToID("_GMethod");

    private static readonly int ID_Bands = Shader.PropertyToID("_Bands");
    private static readonly int ID_OutlineColor = Shader.PropertyToID("_OutlineColor");
    private static readonly int ID_OutlineWidth = Shader.PropertyToID("_OutlineWidth");

    // ── Cache de PropertyBlocks por tag ───────────────────────
    // Dos renderers con el mismo tag comparten el mismo bloque.
    private Dictionary<string, MaterialPropertyBlock> _blockCache
        = new Dictionary<string, MaterialPropertyBlock>();

    // Tags built-in de Unity que ignoramos
    private static readonly HashSet<string> BuiltinTags = new HashSet<string>
    {
        "Untagged", "Respawn", "Finish", "EditorOnly",
        "MainCamera", "Player", "GameController"
    };

    // ──────────────────────────────────────────────────────────
    private void Awake()
    {
        if (config == null)
        {
            Debug.LogError("[MaterialManager] No hay MaterialManagerConfig asignado.", this);
            return;
        }
        config.Initialize();
        ApplyToAllRenderers();
    }

    // ──────────────────────────────────────────────────────────
    private void ApplyToAllRenderers()
    {
        Renderer[] all = FindObjectsOfType<Renderer>();
        int applied = 0;

        foreach (Renderer rend in all)
        {
            string tag = rend.gameObject.tag;
            if (BuiltinTags.Contains(tag)) continue;

            MaterialPropertyBlock block = GetOrCreateBlock(tag);
            if (block == null) continue;

            rend.SetPropertyBlock(block);
            applied++;
        }

        if (debugMode)
            Debug.Log($"[MaterialManager] PropertyBlocks aplicados a {applied} renderers.");
    }

    // ──────────────────────────────────────────────────────────
    private MaterialPropertyBlock GetOrCreateBlock(string tag)
    {
        if (_blockCache.TryGetValue(tag, out MaterialPropertyBlock cached))
            return cached;

        ResolvedMaterialConfig resolved = config.Resolve(tag);
        if (resolved == null) return null;

        MaterialPropertyBlock block = new MaterialPropertyBlock();
        PopulateBlock(block, resolved);
        _blockCache[tag] = block;

        if (debugMode) LogResolved(tag, resolved);

        return block;
    }

    // ──────────────────────────────────────────────────────────
    private void PopulateBlock(MaterialPropertyBlock b, ResolvedMaterialConfig r)
    {
        // ── Comunes ──────────────────────────────────────────
        if (r.ambientLightSet) b.SetColor(ID_AmbientLight, r.ambientLight);
        if (r.KaSet) b.SetColor(ID_Ka, r.Ka);
        if (r.alphaSet) b.SetFloat(ID_Alpha, r.alpha);

        // ── Albedo ────────────────────────────────────────────
        // _AlbedoMode como int: 0 = color, 1 = textura
        // Solo lo leen los shaders NormalMap; los demás lo ignoran.
        if (r.albedoModeSet) b.SetInt(ID_AlbedoMode, r.albedoMode);
        if (r.baseColorSet) b.SetColor(ID_BaseColor, r.baseColor);

        if (r.mainTexSet)
        {
            if (r.mainTex != null)
                b.SetTexture(ID_MainTex, r.mainTex);
            else
                Debug.LogWarning("[MaterialManager] overrideMainTex activo pero textura null. " +
                                 "Asigná una textura o desactivá el flag.");
        }

        // _MainTex_ST agrupa tiling y offset en un Vector4
        if (r.tilingSet || r.offsetSet)
        {
            Vector2 t = r.tilingSet ? r.tiling : Vector2.one;
            Vector2 o = r.offsetSet ? r.offset : Vector2.zero;
            b.SetVector(ID_MainTexST, new Vector4(t.x, t.y, o.x, o.y));
        }

        // ── Normal Map ────────────────────────────────────────
        if (r.normalMapSet)
        {
            if (r.normalMap != null)
                b.SetTexture(ID_NormalMap, r.normalMap);
            else
                Debug.LogWarning("[MaterialManager] overrideNormalMap activo pero textura null. " +
                                 "Asigná una textura o desactivá el flag.");
        }
        if (r.normalStrengthSet) b.SetFloat(ID_NormalStrength, r.normalStrength);

        // ── BP / Toon (compartidos) ───────────────────────────
        if (r.KdSet) b.SetColor(ID_Kd, r.Kd);
        if (r.KsSet) b.SetColor(ID_Ks, r.Ks);
        if (r.materialNSet) b.SetFloat(ID_MaterialN, r.materialN);

        // ── Cook-Torrance ─────────────────────────────────────
        if (r.F0Set) b.SetColor(ID_F0, r.F0);
        if (r.roughnessSet) b.SetFloat(ID_Roughness, r.roughness);
        if (r.dMethodSet) b.SetInt(ID_DMethod, r.dMethod);
        if (r.gMethodSet) b.SetInt(ID_GMethod, r.gMethod);

        // ── Toon ──────────────────────────────────────────────
        if (r.bandsSet) b.SetFloat(ID_Bands, r.bands);
        if (r.outlineColorSet) b.SetColor(ID_OutlineColor, r.outlineColor);
        if (r.outlineWidthSet) b.SetFloat(ID_OutlineWidth, r.outlineWidth);
    }

    // ──────────────────────────────────────────────────────────
    //  API pública: re-aplicar un renderer si su tag cambia
    //  en runtime.
    // ──────────────────────────────────────────────────────────
    public void RefreshRenderer(Renderer rend)
    {
        if (rend == null) return;
        string tag = rend.gameObject.tag;
        if (BuiltinTags.Contains(tag)) return;
        MaterialPropertyBlock block = GetOrCreateBlock(tag);
        if (block != null) rend.SetPropertyBlock(block);
    }

    // ──────────────────────────────────────────────────────────
    private void LogResolved(string tag, ResolvedMaterialConfig r)
    {
        var sb = new System.Text.StringBuilder();
        sb.AppendLine($"[MaterialManager] '{tag}':");
        if (r.ambientLightSet) sb.AppendLine($"  _AmbientLight:   {r.ambientLight}");
        if (r.KaSet) sb.AppendLine($"  _MaterialKa:     {r.Ka}");
        if (r.alphaSet) sb.AppendLine($"  _Alpha:          {r.alpha}");
        if (r.albedoModeSet) sb.AppendLine($"  _AlbedoMode:     {r.albedoMode}  ({(r.albedoMode == 1 ? "Texture" : "Color")})");
        if (r.baseColorSet) sb.AppendLine($"  _BaseColor:      {r.baseColor}");
        if (r.mainTexSet) sb.AppendLine($"  _MainTex:        {r.mainTex?.name ?? "NULL"}");
        if (r.tilingSet) sb.AppendLine($"  tiling:          {r.tiling}");
        if (r.offsetSet) sb.AppendLine($"  offset:          {r.offset}");
        if (r.normalMapSet) sb.AppendLine($"  _NormalMap:      {r.normalMap?.name ?? "NULL"}");
        if (r.normalStrengthSet) sb.AppendLine($"  _NormalStrength: {r.normalStrength}");
        if (r.KdSet) sb.AppendLine($"  _MaterialKd:     {r.Kd}");
        if (r.KsSet) sb.AppendLine($"  _MaterialKs:     {r.Ks}");
        if (r.materialNSet) sb.AppendLine($"  _Material_n:     {r.materialN}");
        if (r.F0Set) sb.AppendLine($"  _F0:             {r.F0}");
        if (r.roughnessSet) sb.AppendLine($"  _Roughness:      {r.roughness}");
        if (r.dMethodSet) sb.AppendLine($"  _DMethod:        {r.dMethod}");
        if (r.gMethodSet) sb.AppendLine($"  _GMethod:        {r.gMethod}");
        if (r.bandsSet) sb.AppendLine($"  _Bands:          {r.bands}");
        if (r.outlineColorSet) sb.AppendLine($"  _OutlineColor:   {r.outlineColor}");
        if (r.outlineWidthSet) sb.AppendLine($"  _OutlineWidth:   {r.outlineWidth}");
        Debug.Log(sb.ToString());
    }
}