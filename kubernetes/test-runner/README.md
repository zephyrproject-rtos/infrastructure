# test-runner

## Dependencies

* cert-manager
* actions-runner-controller

## Deployment Procedure

1. Deploy `cert-manager` component.

    ```
    kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.10.0/cert-manager.yaml
    ```

2. Deploy `actions-runner-controller` component.

    ```
    kubectl create -f https://github.com/actions-runner-controller/actions-runner-controller/releases/download/v0.25.2/actions-runner-controller.yaml
    ```

3. Create `controller-manager` secret.

    ```
    kubectl create secret generic controller-manager \
      -n actions-runner-system \
      --from-literal=github_app_id=${GITHUB_APP_ID} \
      --from-literal=github_app_installation_id=${GITHUB_APP_INSTALL_ID} \
      --from-file=github_app_private_key=${GITHUB_APP_PRIVATE_KEY_FILE_PATH}
    ```

