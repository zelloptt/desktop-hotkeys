{
    "targets": [{
        "target_name": "desktop_hotkeys",
        "cflags!": [ "-fno-exceptions" ],
        "cflags_cc!": [ "-fno-exceptions" ],
        "sources": [
        ],
      	"conditions":[
      		["OS=='mac'", {
      		    "sources": [
      		        "src/HotkeysMac.mm",
      		        "src/main.cpp"
      		    ],
      		    'include_dirs': [
                    "libuiohook/include"
                ],
      		    'libraries': [
                    "Release/uiohook.a"
                ],
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
        'defines': [ 'NAPI_DISABLE_CPP_EXCEPTIONS' ]
    }]
}
