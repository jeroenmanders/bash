# Settings

> Always start a settings-file with the first part of its name (kubernetes:, vault:, ...)
> The reasoning for this that in the future all settings-files could be loaded into memory at once,
> so that settings can be cached and transferred in-memory to other hosts (over SSH, for example) if required.
