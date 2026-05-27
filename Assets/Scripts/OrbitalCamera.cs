using System.Collections.Generic;
using UnityEngine;

/// <summary>
/// Controla la cámara en modo orbital con soporte de focus por objeto.
/// No crea ni destruye la cámara; recibe la referencia desde CameraManager.
/// </summary>
public class OrbitalCamera : MonoBehaviour
{
    // ── Config ─────────────────────────────────────────────────────
    [HideInInspector] public float orbitSpeed = 80f;
    [HideInInspector] public float zoomSpeed  = 60f;

    // ── Dependencias externas ──────────────────────────────────────
    [HideInInspector] public ObjectManager objectManager;
    [HideInInspector] public Transform[]   focusTargets;

    // ── Estado interno ─────────────────────────────────────────────
    private Camera  cam;

    private Vector3 orbitTargetGlobal = new Vector3(110f, 0f, 0f);
    private Vector3 orbitTargetFocus  = new Vector3(10f, 0f, 0f);
    private Vector3 orbitTarget;

    private float orbitDistance = 200f;
    private float orbitYaw      = 180f;
    private float orbitPitch    =  30f;

    private float savedGlobalDistance = 200f;
    private bool  focusMode   = false;
    private int   focusIndex  = 0;
    private int   focusRow    = 0;
    private int   focusColumn = 0;

    // ── GUI state (leído por CameraManager para OnGUI) ────────────
    public bool   ShowTargetUI      = false;
    public string[] OrbitTargetFields = { "110", "0", "0" };

    // ── Propiedades públicas de sólo lectura ───────────────────────
    public Vector3 OrbitTarget  => orbitTarget;
    public bool    FocusMode    => focusMode;
    public float   OrbitSpeed   { get => orbitSpeed;  set => orbitSpeed  = value; }
    public float   ZoomSpeed    { get => zoomSpeed;   set => zoomSpeed   = value; }

    // ──────────────────────────────────────────────────────────────
    //  API pública
    // ──────────────────────────────────────────────────────────────

    /// <summary>Inicializa el modo orbital. Llamar al activar el modo.</summary>
    public void Activate(Camera camera)
    {
        cam = camera;
        orbitTarget = focusMode ? orbitTargetFocus : orbitTargetGlobal;
        Apply();
    }

    /// <summary>Actualiza la lógica orbital. Llamar desde CameraManager.Update().</summary>
    public void Tick()
    {
        if (focusMode) UpdateFocusCycling();

        bool blockArrowRotation = focusMode;

        // Rotación
        if (Input.GetKey(KeyCode.A) || (!blockArrowRotation && Input.GetKey(KeyCode.LeftArrow)))
            orbitYaw -= orbitSpeed * Time.deltaTime;
        if (Input.GetKey(KeyCode.D) || (!blockArrowRotation && Input.GetKey(KeyCode.RightArrow)))
            orbitYaw += orbitSpeed * Time.deltaTime;
        if (Input.GetKey(KeyCode.W) || (!blockArrowRotation && Input.GetKey(KeyCode.UpArrow)))
            orbitPitch += orbitSpeed * Time.deltaTime;
        if (Input.GetKey(KeyCode.S) || (!blockArrowRotation && Input.GetKey(KeyCode.DownArrow)))
            orbitPitch -= orbitSpeed * Time.deltaTime;

        orbitPitch = Mathf.Clamp(orbitPitch, -89f, 89f);

        // Zoom
        if (Input.GetKey(KeyCode.Space))      orbitDistance -= zoomSpeed * Time.deltaTime;
        if (Input.GetKey(KeyCode.LeftShift))  orbitDistance += zoomSpeed * Time.deltaTime;
        orbitDistance = Mathf.Max(1f, orbitDistance);

        Apply();
    }

    /// <summary>Activa o desactiva el modo focus. Llamar desde CameraManager.</summary>
    public void ToggleFocus()
    {
        EnsureFocusTargets();
        if (focusTargets == null || focusTargets.Length == 0) return;

        focusMode = !focusMode;

        if (focusMode)
        {
            savedGlobalDistance = orbitDistance;
            orbitDistance = 100f; 
            ApplyFocusTarget(focusIndex, true);
        }
        else
        {
            orbitDistance = savedGlobalDistance;
            RestoreFocusTargets();
        }
    }

    /// <summary>
    /// Actualiza el target global (p. ej. desde el grid center).
    /// También puede actualizar los parámetros orbitales derivados del offset.
    /// </summary>
    public void SetGlobalTarget(Vector3 target, Vector3 orbitOffset)
    {
        orbitTargetGlobal = target;
        OrbitTargetFields[0] = orbitTargetGlobal.x.ToString("F1");
        OrbitTargetFields[1] = orbitTargetGlobal.y.ToString("F1");
        OrbitTargetFields[2] = orbitTargetGlobal.z.ToString("F1");

        float dist = orbitOffset.magnitude;
        if (dist > 0.001f)
        {
            orbitDistance = dist;
            Vector3 dir = orbitOffset / dist;
            orbitPitch = Mathf.Asin(Mathf.Clamp(dir.y, -1f, 1f)) * Mathf.Rad2Deg;
            orbitYaw   = Mathf.Atan2(dir.x, dir.z) * Mathf.Rad2Deg;
        }

        if (!focusMode)
        {
            orbitTarget = orbitTargetGlobal;
            if (cam != null) Apply();
        }
    }

    /// <summary>Aplica un target manual introducido por GUI.</summary>
    public void ApplyManualTarget(Vector3 target)
    {
        orbitTargetGlobal = target;
        orbitTarget       = orbitTargetGlobal;
        Apply();
    }

    // ──────────────────────────────────────────────────────────────
    //  Privados
    // ──────────────────────────────────────────────────────────────

    void Apply()
    {
        float pitchRad = orbitPitch * Mathf.Deg2Rad;
        float yawRad   = orbitYaw   * Mathf.Deg2Rad;

        Vector3 offset = new Vector3(
            Mathf.Cos(pitchRad) * Mathf.Sin(yawRad),
            Mathf.Sin(pitchRad),
            Mathf.Cos(pitchRad) * Mathf.Cos(yawRad)
        ) * orbitDistance;

        cam.transform.position = orbitTarget + offset;
        cam.transform.LookAt(orbitTarget, Vector3.up);
    }

    void UpdateFocusCycling()
    {
        if (focusTargets == null || focusTargets.Length == 0) return;

        int rows    = objectManager != null ? objectManager.Rows    : 0;
        int columns = objectManager != null ? objectManager.Columns : 0;
        bool hasGrid = rows > 0 && columns > 0;

        if (hasGrid && focusTargets.Length != rows * columns)
        {
            focusTargets = objectManager.GetTeapotTransforms();
            if (focusTargets.Length == 0) return;
        }

        bool moved    = false;
        int  newRow   = focusRow;
        int  newCol   = focusColumn;

        if (Input.GetKeyDown(KeyCode.UpArrow))
        {
            newRow = hasGrid ? (focusRow - 1 + rows) % rows : focusRow;
            moved  = true;
        }
        if (Input.GetKeyDown(KeyCode.DownArrow))
        {
            newRow = hasGrid ? (focusRow + 1) % rows : focusRow;
            moved  = true;
        }
        if (Input.GetKeyDown(KeyCode.LeftArrow))
        {
            if (hasGrid)
            {
                if (focusColumn == 0) { newRow = (focusRow - 1 + rows) % rows; newCol = columns - 1; }
                else                  { newCol = focusColumn - 1; }
            }
            moved = true;
        }
        if (Input.GetKeyDown(KeyCode.RightArrow))
        {
            if (hasGrid)
            {
                if (focusColumn == columns - 1) { newRow = (focusRow + 1) % rows; newCol = 0; }
                else                            { newCol = focusColumn + 1; }
            }
            moved = true;
        }

        if (!moved) return;

        focusRow    = newRow;
        focusColumn = newCol;

        if (hasGrid)
        {
            ApplyFocusTarget(focusRow * columns + focusColumn, false);
            return;
        }

        int dir = 0;
        if (Input.GetKeyDown(KeyCode.RightArrow) || Input.GetKeyDown(KeyCode.DownArrow)) dir =  1;
        if (Input.GetKeyDown(KeyCode.LeftArrow)  || Input.GetKeyDown(KeyCode.UpArrow))   dir = -1;
        if (dir == 0) return;

        ApplyFocusTarget((focusIndex + dir + focusTargets.Length) % focusTargets.Length, false);
    }

    void ApplyFocusTarget(int index, bool force)
    {
        if (focusTargets == null || focusTargets.Length == 0) return;
        if (!force && index == focusIndex) return;

        focusIndex = Mathf.Clamp(index, 0, focusTargets.Length - 1);

        if (objectManager != null)
        {
            int cols = objectManager.Columns;
            if (cols > 0)
            {
                focusRow    = focusIndex / cols;
                focusColumn = focusIndex % cols;
            }
        }

        Transform target = focusTargets[focusIndex];
        if (target == null) return;

        Vector3 targetCenter = target.position;
        var renderers = target.GetComponentsInChildren<Renderer>(true);
        if (renderers.Length > 0)
        {
            Bounds bounds = renderers[0].bounds;
            for (int i = 1; i < renderers.Length; i++)
                bounds.Encapsulate(renderers[i].bounds);
            targetCenter = bounds.center;
        }

        orbitTargetFocus = targetCenter;
        orbitTarget      = orbitTargetFocus;
        Apply();

        for (int i = 0; i < focusTargets.Length; i++)
        {
            if (focusTargets[i] != null)
                focusTargets[i].gameObject.SetActive(i == focusIndex);
        }
    }

    void RestoreFocusTargets()
    {
        if (focusTargets == null) return;
        foreach (var t in focusTargets)
            if (t != null) t.gameObject.SetActive(true);

        orbitTarget = orbitTargetGlobal;
        Apply();
    }

    void EnsureFocusTargets()
    {
        if (focusTargets != null && focusTargets.Length > 0) return;

        if (objectManager != null)
        {
            focusTargets = objectManager.GetTeapotTransforms();
            if (focusTargets.Length > 0)
            {
                int cols   = objectManager.Columns;
                focusIndex = Mathf.Clamp(focusIndex, 0, focusTargets.Length - 1);
                focusRow   = cols > 0 ? focusIndex / cols : 0;
                focusColumn = cols > 0 ? focusIndex % cols : 0;
                return;
            }
        }

        var renderers = FindObjectsOfType<Renderer>(true);
        var unique    = new HashSet<Transform>();
        var list      = new List<Transform>();

        foreach (var r in renderers)
        {
            if (r == null) continue;
            Transform root = r.transform.root;
            if (root == null || root == transform) continue;
            if (unique.Add(root)) list.Add(root);
        }

        focusTargets = list.ToArray();

        if (focusTargets.Length == 0)
            Debug.LogWarning("OrbitalCamera: no se encontraron objetos para focus.");
    }
}
