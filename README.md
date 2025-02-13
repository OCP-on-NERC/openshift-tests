## Cloning this repository

You must clone this repository with submodules enabled:

```
git clone --recurse-submodules https://github.com/OCP-on-NERC/openshift-tests
```

Or initialize submodules after cloning it:

```
git clone https://github.com/OCP-on-NERC/openshift-tests
cd openshift-tests
git submodule update --init
```

## Requirements

- You will need the following software available on the system on which you are running these tests:

  - [`kubectl`](https://kubernetes.io/docs/tasks/tools/#kubectl)

    These tests use `kubectl` for interacting with Kubernetes clusters. You can
    also use the `oc` command by setting `KUBECTL=oc` in your environment
    before running the tests.

  - GNU [`coreutils`](https://www.gnu.org/software/coreutils/)

    These tests make extensive use of the `timeout` command from the
    `coreutils` package. If you are on Linux you will already have this.

  - [`jq`](https://stedolan.github.io/jq/)

    `jq` is a tool for parsing JSON data.

- You must be able to create resources in `$TARGET_NAMESPACE` (see below). Some of the tests may require cluster-admin privileges; you can disable these tests by setting `SKIP_CLUSTER_ADMIN_TESTS=1`.

## Configuration

Tests can be configured using the following environment variables.

### General configuration

- `TARGET_NAMESPACE` -- any commands the create or interact with namespaced resources will use this namespace (`default` by default).
- `SKIP_CLUSTER_ADMIN_TESTS` -- skip tests that require elevated privileges.

### External secrets

- `SECRET_PATH` -- the secret id in the vault

To test a `SecretStore`, you need to provide:

- `CLUSTER_SECRET_STORE_NAME` -- the name of the `ClusterSecretStore` resource

To test a namespaced `SecretStore` you need to provide:

- `SECRET_STORE_NAME` -- the name of the `SecretStore` resource (which must exist in the `$TARGET_NAMESPACE`).

## Running the tests

Use the `run-tests.sh` script:

```
./run-tests.sh
```

Look [here](https://asciinema.org/a/y8eiXuPGtpGZxwqoMXuXURVtK) to see an example test run.
