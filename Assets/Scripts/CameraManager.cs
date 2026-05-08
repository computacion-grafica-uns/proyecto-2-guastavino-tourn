using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class CameraManager : MonoBehaviour
{
    private Vector3 pos = new Vector3(5, 1, -10);
    private bool orbitalMode = false;
    private float orbitDistance = 30f;
    private float orbitYaw = 0f;
    private float orbitPitch = 30f;
    private Vector3 orbitTarget = new Vector3(5f, 0f, 5f);

    private float cameraSpeed = 6f;
    private float orbitSpeed = 2f;
    private float yaw = 0f;
    private float pitch = 0f;

    void Start()
    {
        
    }

    // Update is called once per frame
    void Update()
    {
        if (Input.GetKeyDown(KeyCode.Tab))
        {
            orbitalMode = !orbitalMode;
        }

        if (orbitalMode)
            UpdateOrbital();
        else
            UpdateFirstPerson();
    }


    private void UpdateOrbital()
    {
        if (Input.GetKey(KeyCode.A) || Input.GetKey(KeyCode.LeftArrow)) orbitYaw += orbitSpeed * 50f * Time.deltaTime;
        if (Input.GetKey(KeyCode.D) || Input.GetKey(KeyCode.RightArrow)) orbitYaw -= orbitSpeed * 50f * Time.deltaTime;
        if (Input.GetKey(KeyCode.W) || Input.GetKey(KeyCode.UpArrow)) orbitPitch += orbitSpeed * 50f * Time.deltaTime;
        if (Input.GetKey(KeyCode.S) || Input.GetKey(KeyCode.DownArrow)) orbitPitch -= orbitSpeed * 50f * Time.deltaTime;

        if (Input.GetKey(KeyCode.Space)) orbitDistance -= cameraSpeed * 2f * Time.deltaTime;
        if (Input.GetKey(KeyCode.LeftShift)) orbitDistance += cameraSpeed * 2f * Time.deltaTime;

        float pitchRad = orbitPitch * Mathf.Deg2Rad;
        float yawRad = orbitYaw * Mathf.Deg2Rad;

        pos = orbitTarget + new Vector3(
            Mathf.Cos(pitchRad) * Mathf.Sin(yawRad),
            Mathf.Sin(pitchRad),
            Mathf.Cos(pitchRad) * Mathf.Cos(yawRad)
        ) * orbitDistance;

        transform.position = pos;
        transform.LookAt(orbitTarget);
    }
    private void UpdateFirstPerson()
    {
        float rotateHorizontal = 0f;
        float rotateVertical = 0f;

        if (Input.GetKey(KeyCode.LeftArrow)) rotateHorizontal = -1f;
        if (Input.GetKey(KeyCode.RightArrow)) rotateHorizontal = 1f;
        if (Input.GetKey(KeyCode.UpArrow)) rotateVertical = -1f;
        if (Input.GetKey(KeyCode.DownArrow)) rotateVertical = +1f;

        float rotationSpeed = 80f;

        yaw += rotateHorizontal * rotationSpeed * Time.deltaTime;
        pitch += rotateVertical * rotationSpeed * Time.deltaTime;

        pitch = Mathf.Clamp(pitch, -89f, 89f);

        Quaternion rotation = Quaternion.Euler(pitch, yaw, 0);

        Vector3 forward = rotation * Vector3.forward;
        Vector3 right = rotation * Vector3.right;

        Vector3 moveDir = Vector3.zero;

        if (Input.GetKey(KeyCode.W)) moveDir += forward;
        if (Input.GetKey(KeyCode.S)) moveDir -= forward;
        if (Input.GetKey(KeyCode.A)) moveDir -= right;
        if (Input.GetKey(KeyCode.D)) moveDir += right;

        if (Input.GetKey(KeyCode.Space)) moveDir += Vector3.up;
        if (Input.GetKey(KeyCode.LeftShift)) moveDir -= Vector3.up;

        pos += moveDir.normalized * cameraSpeed * Time.deltaTime;

        transform.position = pos;
        transform.rotation = rotation;
    }
}
