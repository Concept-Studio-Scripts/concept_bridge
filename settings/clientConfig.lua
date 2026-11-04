BridgeClientConfig                   = {}
BridgeClientConfig.InputSystem       = "auto"       -- [ auto | ox_lib | lation_ui | qb-input ]
BridgeClientConfig.MenuSystem        = "auto"       -- [ auto | ox_lib | wasabi_uikit | lation_ui | qb-menu ]
BridgeClientConfig.ProgressBarSystem = "auto"       -- [ auto | ox_lib | wasabi_uikit | lation_ui | ZSX_UIV2 | keep-progressbar | progressbar | msk_core ]
-- Fuel / VehicleKey / Target providers are detected from started resources
-- (see modules/fuel, modules/vehiclekey, modules/target).
BridgeClientConfig.Seatbelt          = "auto"       -- [ auto | qbx_seatbelt | qb-smallresources | esx_cruisecontrol | concept_seatbelt | none ]
BridgeClientConfig.Voice             = "auto"       -- [ auto | pma-voice | none ]
BridgeClientConfig.Debug             = false
return BridgeClientConfig
