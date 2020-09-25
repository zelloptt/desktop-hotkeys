{
	"targets": [{
		"target_name": "uiohook",
		"type": "static_library",
		"sources": [
			"uiohook/include/uiohook.h",
			"uiohook/src/logger.c",
			"uiohook/src/logger.h",
			"uiohook/src/darwin/input_helper.h",
			"uiohook/src/darwin/input_helper.c",
			"uiohook/src/darwin/input_hook.c",
			"uiohook/src/darwin/post_event.c",
			"uiohook/src/darwin/system_properties.c"
		],
		"include_dirs": [
			'node_modules/nan',
			'uiohook/include',
			'uiohook/src',
			'uiohook/src/darwin'
		],
        "defines": [
            'USE_OBJC',
            'USE_IOKIT',
            'USE_APPLICATION_SERVICES',
            'ENABLE_STATIC'
            'BUILD_DEMO'
             ],
        "libraries": [
             	'-framework CoreFoundation',
             	'-framework Cocoa',
             	'-framework IOKit',
             	'-framework Carbon'
             ]
	}]
}