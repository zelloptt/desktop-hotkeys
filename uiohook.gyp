{
	"targets": [{
		"target_name": "uiohook",
		"type": "static_library",
		"sources": [
			"libuiohook/include/uiohook.h",
			"libuiohook/src/logger.c",
			"libuiohook/src/logger.h",
			"libuiohook/src/darwin/input_helper.h",
			"libuiohook/src/darwin/input_helper.c",
			"libuiohook/src/darwin/input_hook.c",
			"libuiohook/src/darwin/post_event.c",
			"libuiohook/src/darwin/system_properties.c"
		],
		"include_dirs": [
			'node_modules/nan',
			'libuiohook/include',
			'libuiohook/src',
			'libuiohook/src/darwin'
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