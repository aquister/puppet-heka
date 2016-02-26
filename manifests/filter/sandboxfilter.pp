# The sandbox filter provides an isolated execution environment for data analysis.
# Any output generated by the sandbox is injected into the payload of a new message
# for further processing or to be output. 
#
# === Parameters:
#
# $ensure::                       This is used to set the status of the config file: present or absent
#                                 Default: present
#
### Common Filter Parameters ###
#
# $message_matcher::              Boolean expression, when evaluated to true passes the message to the filter for processing.
#                                 Defaults to matching nothing
#                                 Type: string
#
# $message_signer::               The name of the message signer. If specified only messages with this signer are passed to the filter
#                                 for processing.
#                                 Type: string
#
# $ticker_interval::              Frequency (in seconds) that a timer event will be sent to the filter.
#                                 Defaults to not sending timer events.
#                                 Type: string
#
# $can_exit::                     Whether or not this plugin can exit without causing Heka to shutdown.
#                                 Defaults to false.
#                                 Type: bool
#
### Buffering::
# All of the buffering config options are set to the standard default options, except for
# cursor_update_count, which is set to 50 instead of the standard default of 1.
#
# $use_buffering::                A boolean that decides if buffering is used or not
#                                 Default: false
#                                 Type: bool
#
# $max_file_size::                The maximum size (in bytes) of a single file in the queue buffer.
#                                 When a message would increase a queue file to greater than this size, the message will be written
#                                 into a new file instead.
#                                 Value cannot be zero, if zero is specified the default will instead be used.
#                                 Defaults to 512MiB.
#                                 Type: uint64
#
# $max_buffer_size::              Maximum amount of disk space (in bytes) that the entire queue buffer can consume.
#                                 The action taken when the maximum buffer size is reached is determined by the full_action setting.
#                                 Defaults to 0, or no limit.
#                                 Type: uint64
#
# $full_action::                  The action Heka will take if the queue buffer grows to larger than the maximum specified by
#                                 the max_buffer_size setting. Must be one of the following values:
#                                 - shutdown: Heka will stop all processing and attempt a clean shutdown.
#                                 - drop: Heka will drop the current message and will continue to process future messages.
#                                 - block: Heka will pause message delivery, applying back pressure through the router to the inputs.
#                                          Delivery will resume if and when the queue buffer size reduces to below the specified maximum.
#                                 Defaults to shutdown, although specific plugins might override this default with a default of their own.
#                                 Type: string
#
# $cursor_update_count::          A plugin is responsible for notifying the queue buffer when a message has been processed by
#                                 calling an UpdateCursor method on the PluginRunner. Some plugins call this for every message,
#                                 while others call it only periodically after processing a large batch of messages.
#                                 This setting specifies how many UpdateCursor calls must be made before the cursor location is flushed to disk.
#                                 Value cannot be zero, if zero is specified the default will be used instead.
#                                 Defaults to 1, although specific plugins might override this default with a default of their own.
#                                 Type: uint
#
### Common Sandbox Parameters
#
# $script_type::                  The language the sandbox is written in. Currently the only valid option is 'lua' which is the
#                                 default.
#
# $filename::                     The path to the sandbox code; if specified as a relative path it will be appended to Heka's global
#                                 share_dir.
#
# $preserve_data::                True if the sandbox global data should be preserved/restored on plugin shutdown/startup.
#                                 When true this works in conjunction with a global Lua _PRESERVATION_VERSION variable which
#                                 is examined during restoration; if the previous version does not match the current version
#                                 the restoration will be aborted and the sandbox will start cleanly. _PRESERVATION_VERSION should
#                                 be incremented any time an incompatible change is made to the global data schema. If no version
#                                 is set the check will always succeed and a version of zero is assumed.
#
# $memory_limit::                 The number of bytes the sandbox is allowed to consume before being terminated (default 8MiB).
#
# $instruction_limit::            The number of instructions the sandbox is allowed to execute during the
#                                 process_message/timer_event functions before being terminated (default 1M).
#
# $output_limit::                 The number of bytes the sandbox output buffer can hold before being terminated (default 63KiB).
#                                 Warning: messages exceeding 64KiB will generate an error and be discarded by the standard output
#                                 plugins (File, TCP, UDP) since they exceed the maximum message size.
#
# $module_directory::             The directory where 'require' will attempt to load the external Lua modules from. Defaults to ${SHARE_DIR}/lua_modules.
#
# $config::                       A map of configuration variables available to the sandbox via read_config.
#                                 The map consists of a string key with: string, bool, int64, or float64 values.
#
### SandboxFilter Parameters
#
# $timer_event_on_shutdown::      True if the sandbox should have its timer_event function called on shutdown.
#                                 Type: bool
#
define heka::filter::sandboxfilter (
  $ensure                  = 'present',
  # Common Filter Parameters
  $message_matcher         = undef,
  $message_signer          = undef,
  $ticker_interval         = undef,
  $can_exit                = undef,
  $use_buffering           = undef,
  # Buffering
  $max_file_size           = undef,
  $max_buffer_size         = undef,
  $full_action             = undef,
  $cursor_update_count     = undef,
  # Common Sandbox Parameters
  $script_type             = 'lua',
  # lint:ignore:parameter_order
  $filename,
  # lint:endignore
  $preserve_data           = undef,
  $memory_limit            = undef,
  $instruction_limit       = undef,
  $output_limit            = undef,
  $module_directory        = undef,
  $config                  = undef,
  # SandboxFilter Parameters
  $timer_event_on_shutdown = undef,
) {
  validate_re($ensure, '^(present|absent)$')
  # Common Filter Parameters
  if $message_matcher { validate_string($message_matcher) }
  if $message_signer { validate_string($message_signer) }
  if $ticker_interval { validate_integer($ticker_interval) }
  if $can_exit { validate_bool($can_exit) }
  if $use_buffering { validate_bool($use_buffering) }
  # Buffering
  if $max_file_size { validate_integer($max_file_size) }
  if $max_buffer_size { validate_integer($max_buffer_size) }
  if $full_action { validate_re($full_action, '^(shutdown|drop|block)$') }
  if $cursor_update_count { validate_integer($cursor_update_count) }
  # Common Sandbox Parameters
  validate_string($filename)
  if $preserve_data { validate_bool($preserve_data) }
  if $memory_limit { validate_integer($memory_limit) }
  if $instruction_limit { validate_integer($instruction_limit) }
  if $output_limit { validate_integer($output_limit) }
  if $module_directory { validate_string($module_directory) }
  # SandboxFilter Parameters
  if $timer_event_on_shutdown { validate_bool($timer_event_on_shutdown) }

  $full_name = "sandboxfilter_${name}"
  heka::snippet { $full_name:
    ensure  => $ensure,
    content => template("${module_name}/filter/sandboxfilter.toml.erb"),
  }
}