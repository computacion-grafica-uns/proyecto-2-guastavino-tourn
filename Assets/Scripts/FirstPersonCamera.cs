using UnityEngine;

/// <summary>
/// Controla el movimiento y rotación en modo primera persona.
/// No crea ni destruye la cámara; recibe la referencia desde CameraManager.
/// </summary>
public class FirstPersonCamera : MonoBehaviour
{
    // ── Config ─────────────────────────────────────────────────────
    [HideInInspector] public float moveSpeed  = 100f;
    [HideInInspector] public float rotSpeed   =  90f;

    // ── Estado interno ─────────────────────────────────────────────
    private Camera cam;
    private Vector3 fpPos;
    private float   yaw;
    private float   pitch;

    // ──────────────────────────────────────────────────────────────
    //  API pública
    // ──────────────────────────────────────────────────────────────

    /// <summary>
    /// Inicializa el modo tomando la posición y rotación actuales de la cámara.
    /// Llamar cada vez que se activa este modo.
    /// </summary>
    public void Activate(Camera camera)
    {
        cam   = camera;
        fpPos = cam.transform.position;

        Vector3 euler = cam.transform.eulerAngles;
        yaw   = euler.y;
        pitch = euler.x;

        Apply();
    }

    /// <summary>
    /// Actualiza el movimiento/rotación. Llamar desde CameraManager.Update().
    /// </summary>
    public void Tick()
    {
        HandleRotation();
        HandleMovement();
        Apply();
    }

    // ──────────────────────────────────────────────────────────────
    //  Privados
    // ──────────────────────────────────────────────────────────────

    void HandleRotation()
    {
        if (Input.GetKey(KeyCode.LeftArrow))  yaw   -= rotSpeed * Time.deltaTime;
        if (Input.GetKey(KeyCode.RightArrow)) yaw   += rotSpeed * Time.deltaTime;
        if (Input.GetKey(KeyCode.DownArrow))  pitch += rotSpeed * Time.deltaTime;
        if (Input.GetKey(KeyCode.UpArrow))    pitch -= rotSpeed * Time.deltaTime;

        pitch = Mathf.Clamp(pitch, -89f, 89f);
    }

    void HandleMovement()
    {
        var     rot         = Quaternion.Euler(pitch, yaw, 0f);
        Vector3 forward     = rot * Vector3.forward;
        Vector3 right       = rot * Vector3.right;
        Vector3 flatForward = new Vector3(forward.x, 0f, forward.z).normalized;
        Vector3 moveDir     = Vector3.zero;

        if (Input.GetKey(KeyCode.W))          moveDir += flatForward;
        if (Input.GetKey(KeyCode.S))          moveDir -= flatForward;
        if (Input.GetKey(KeyCode.A))          moveDir -= right;
        if (Input.GetKey(KeyCode.D))          moveDir += right;
        if (Input.GetKey(KeyCode.Space))      moveDir += Vector3.up;
        if (Input.GetKey(KeyCode.LeftShift))  moveDir -= Vector3.up;

        if (moveDir != Vector3.zero)
            fpPos += moveDir.normalized * moveSpeed * Time.deltaTime;
    }

    void Apply()
    {
        cam.transform.position = fpPos;
        cam.transform.rotation = Quaternion.Euler(pitch, yaw, 0f);
    }
}
