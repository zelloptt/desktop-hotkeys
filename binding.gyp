{
    "targets": [{
        "target_name": "desktop_hotkeys",
        "cflags!": [ "-fno-exceptions" ],
        "cflags_cc!": [ "-fno-exceptions" ],
        "sources": [
            	"src/main.cpp"
        ],
      	"conditions":[
      		["OS=='mac'", {
      	  		"sources": [ "src/HotkeysMac.cpp" ],
                    "cflags+": ["-fvisibility=hidden"],
                    "xcode_settings": {
                      "GCC_SYMBOLS_PRIVATE_EXTERN": "YES"
                    }
      		}],
        	["OS=='win'", {
      	  		"sources": [
	             		"src/Hotkeys.cpp",
				"src/HotkeyManager.cpp",
 			]                     
      		}]
      	], 
        'include_dirs': [
            "<!@(node -p \"require('node-addon-api').include\")"
        ],
        'libraries': [],
        'dependencies': [
            "<!(node -p \"require('node-addon-api').gyp\")"
        ],
        'defines': [ 'NAPI_DISABLE_CPP_EXCEPTIONS' ]
    }]
}
