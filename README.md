### Welcome to Dashbase Quickstart

Refer to the [Wiki](https://github.com/dashbase/dashbase-quickstart/wiki) to get started!

### Changing tag to use `nightly`

The `latest` tag is the equivalent to the latest released version of Dashbase. To use the `nightly` tag, change all services in `docker-stack-core.yml` that have the `latest` tag to `nightly` and re-deploy the stack.

To change table tag, you can either specify the `--tag nightly` option when running the `create_table` tool, or you can manually change the tags within your stack yaml from `latest` to `nightly`.
