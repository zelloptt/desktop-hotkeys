{
    "targets": [{
        "target_name": "<(module_name)",
        "cflags!": [ "-fno-exceptions" ],
        "cflags_cc!": [ "-fno-exceptions" ],
        "sources": [
        ],
      	"conditions":[
      		["OS=='mac'", {
      		    "sources": [
      		        "src/AddonMac.mm",
      		        "src/AccessibilityMac.mm",
      		        "src/HotkeysMac.mm",
      		        "src/main.cpp"
      		    ],
      		    'include_dirs': [
                    "libuiohook/include"
                ],
                'configurations': {
                    'Debug': {
                       'xcode_settings': {
                          'OTHER_LDFLAGS': [
                          ]
                       }
                    },
                    'Release': {
                        'xcode_settings': {
                           'OTHER_LDFLAGS': [
                           ]
                        }
                    }
                },
                'dependencies': [
                    "./uiohook.gyp:uiohook"
                ],
                "cflags+": ["-fvisibility=hidden"],
                "xcode_settings": {
                "GCC_SYMBOLS_PRIVATE_EXTERN": "YES"
                }
      		}],
        	["OS=='win'", {
      	  		"sources": [
            	"src/main.cpp",
	            "src/Hotkeys.cpp",
				"src/HotkeyManager.cpp"
 			]                     
      		}],
        	["OS=='linux'", {
      	  		"sources": [
            	"src/main.cpp",
	            "src/HotkeysLinuxEmptyImpl.cpp"
 			]
      		}]
      	],
        'include_dirs': [
            "<!@(node -p \"require('node-addon-api').include\")"
        ],
        'dependencies': [
            "<!(node -p \"require('node-addon-api').gyp\")"
        ],
        'defines': [ 'NAPI_VERSION=<(napi_build_version)', 'NAPI_DISABLE_CPP_EXCEPTIONS' ]
    },
    {
      'target_name': 'action_after_build',
      'type': 'none',
      'dependencies': [ "<(module_name)" ],
      'copies': [
          {
            'files': [ '<(PRODUCT_DIR)/<(module_name).node' ],
            'destination': '<(module_path)'
          }
      ]
    }

]
}
