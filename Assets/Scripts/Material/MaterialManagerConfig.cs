using UnityEngine;
using System.Collections.Generic;

// ============================================================
//  MaterialManagerConfig.cs
//  ScriptableObject central: contiene todos los nodos de la
//  jerarquía y expone un método para resolver la config final
//  de un tag dado, aplicando herencia de izquierda a derecha.
//
//  Ejemplo de resolución para "bp_cuero_sillas":
//    1. busca "base"           → aplica como base
//    2. busca "bp"             → sobreescribe lo que define
//    3. busca "bp_cuero"       → sobreescribe lo que define
//    4. busca "bp_cuero_sillas"→ sobreescribe lo que define
//    Resultado = merge de los 4 niveles
// ============================================================

[CreateAssetMenu(fileName = "MaterialManagerConfig", menuName = "MaterialManager/MaterialManagerConfig")]
public class MaterialManagerConfig : ScriptableObject
{
    [Tooltip("Lista de todos los nodos de la jerarquía de tags.")]
    public List<MaterialConfig> nodes = new List<MaterialConfig>();

    // Diccionario interno para búsqueda O(1)
    private Dictionary<string, MaterialConfig> _dict;

    // --------------------------------------------------------
    //  Inicialización del diccionario
    // --------------------------------------------------------
    public void Initialize()
    {
        _dict = new Dictionary<string, MaterialConfig>();
        foreach (var node in nodes)
        {
            if (node == null || string.IsNullOrEmpty(node.tagKey))
                continue;

            if (!_dict.ContainsKey(node.tagKey))
                _dict.Add(node.tagKey, node);
            else
                Debug.LogWarning($"[MaterialManagerConfig] Tag duplicado ignorado: '{node.tagKey}'");
        }
    }

    // --------------------------------------------------------
    //  Resuelve la configuración final para un tag dado.
    //  Devuelve una ResolvedMaterialConfig con todos los
    //  valores ya mergeados.
    // --------------------------------------------------------
    public ResolvedMaterialConfig Resolve(string tag)
    {
        if (_dict == null) Initialize();

        ResolvedMaterialConfig resolved = new ResolvedMaterialConfig();

        // Siempre intentamos aplicar "base" primero
        TryMerge(resolved, "base");

        // Luego acumulamos término a término
        string[] terms = tag.Split('_');
        string accumulated = "";

        foreach (string term in terms)
        {
            accumulated = accumulated == "" ? term : accumulated + "_" + term;

            // "base" ya fue aplicado arriba, no lo repetimos
            if (accumulated == "base") continue;

            TryMerge(resolved, accumulated);
        }

        return resolved;
    }

    // --------------------------------------------------------
    //  Aplica un nodo al resolved si existe en el diccionario
    // --------------------------------------------------------
    private void TryMerge(ResolvedMaterialConfig resolved, string key)
    {
        if (_dict == null) return;
        if (_dict.TryGetValue(key, out MaterialConfig config))
            resolved.MergeWith(config);
    }
}