# runner-repo-cache

The runner-repo-cache component provides an EFS-backed dynamically provisioned
persistent volume storing the cached Git repositories to be used in the CI
workflows.

The cached Git repositories stored in the persistent volume are periodically
updated via a CronJob.

The repository cache synchronisation process is implemented by the
[repo-cache-sync] Docker image.

[repo-cache-sync]: https://github.com/zephyrproject-rtos/docker-ci-zephyr-runner
