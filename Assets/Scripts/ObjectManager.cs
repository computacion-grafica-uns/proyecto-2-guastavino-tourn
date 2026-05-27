using UnityEngine;

public class ObjectManager : MonoBehaviour
{
    private int rows = 3;
    private int columns = 6;
    private Vector3 spacing = new Vector3(90f, 60f, 0f);
    public GameObject teapotPrefab;
    public Vector3 teapotScale = new Vector3(0.01f, 0.01f, 0.01f);

    [Header("Materiales por fila")]
    public Material[] blinnPhongMaterials;
    public Material[] cookTorranceMaterials;
    public Material[] toonMaterials;

    private Transform[,] teapotGrid;

    public int Rows => rows;
    public int Columns => columns;

    void Start()
    {
        if (teapotPrefab == null)
        {
            Debug.LogError("ObjectManager: teapotPrefab is not assigned.");
            return;
        }

        teapotGrid = new Transform[rows, columns];

        float totalWidth = (columns - 1) * spacing.x;
        float totalHeight = (rows - 1) * spacing.y;
        Vector3 start = transform.position - new Vector3(totalWidth * 0.5f, totalHeight * 0.5f, 0f);

        string[] x = { "barro", "metal", "transparente", "mapeo2D", "procedural", "normalMapping" };
        string[] y = { "blinnPhong", "cookTorrance", "toon" };

        for (int r = 0; r < rows; r++)
        {
            for (int c = 0; c < columns; c++)
            {
                Vector3 pos = start + new Vector3(c * spacing.x, - r * spacing.y, 0f);
                var instance = Instantiate(teapotPrefab, pos, Quaternion.identity, transform);
                instance.transform.localScale = teapotScale;
                instance.name = $"Teapot_{x[c]}_{y[r]}";
                teapotGrid[r, c] = instance.transform;

                Material material = GetMaterialForCell(r, c);
                ApplyMaterial(instance, material, r, c);
            }
        }
    }

    Material GetMaterialForCell(int row, int column)
    {
        Material[] rowMaterials = null;
        switch (row)
        {
            case 0:
                rowMaterials = blinnPhongMaterials;
                break;
            case 1:
                rowMaterials = cookTorranceMaterials;
                break;
            case 2:
                rowMaterials = toonMaterials;
                break;
        }

        if (rowMaterials == null || rowMaterials.Length == 0) return null;
        if (column < 0 || column >= rowMaterials.Length) return null;
        return rowMaterials[column];
    }

    void ApplyMaterial(GameObject instance, Material material, int row, int column)
    {
        if (instance == null) return;
        if (material == null)
        {
            Debug.LogWarning($"ObjectManager: missing material for row {row}, column {column} in object {instance}.");
            return;
        }

        var renderers = instance.GetComponentsInChildren<Renderer>(true);
        for (int i = 0; i < renderers.Length; i++)
        {
            renderers[i].sharedMaterial = material;
        }
    }

    public Transform GetTeapot(int row, int column)
    {
        if (teapotGrid == null) return null;
        if (row < 0 || row >= rows) return null;
        if (column < 0 || column >= columns) return null;
        return teapotGrid[row, column];
    }

    public Transform[] GetTeapotTransforms()
    {
        if (teapotGrid == null) return new Transform[0];

        var list = new Transform[rows * columns];
        int index = 0;
        for (int r = 0; r < rows; r++)
        {
            for (int c = 0; c < columns; c++)
            {
                list[index++] = teapotGrid[r, c];
            }
        }

        return list;
    }
}
