#+feature dynamic-literals
package main

import "base:runtime"
import "core:c"
import "core:fmt"
import "vendor:glfw"
import "vendor:vulkan"

error_callback :: proc "c" (code: i32, desc: cstring) {
	context = runtime.default_context()
	fmt.println(desc, code)
}

key_callback :: proc "c" (window: glfw.WindowHandle, key, scancode, action, mods: i32) {
	if (key == glfw.KEY_ESCAPE && action == glfw.PRESS) ||
	   (key == glfw.KEY_Q && action == glfw.PRESS) {
		glfw.SetWindowShouldClose(window, glfw.TRUE)
	}
}

vkInstance: vulkan.Instance = vulkan.Instance{}
vkAppInfo: vulkan.ApplicationInfo = {
	sType              = vulkan.StructureType.APPLICATION_INFO,
	pApplicationName   = "Triangle",
	applicationVersion = vulkan.MAKE_VERSION(1, 0, 0),
	pEngineName        = "no engine",
	apiVersion         = vulkan.MAKE_VERSION(1, 3, 280),
}
vkInstanceInfo: vulkan.InstanceCreateInfo = {
	sType                   = vulkan.StructureType.INSTANCE_CREATE_INFO,
	pApplicationInfo        = &vkAppInfo,
	enabledLayerCount       = 0,
}

//https://www.glfw.org/docs/3.3/vulkan_guide.html
createVkInstance :: proc() {
	requiredExtensions := glfw.GetRequiredInstanceExtensions()

	vkInstanceInfo.enabledExtensionCount = u32(len(requiredExtensions))
	vkInstanceInfo.ppEnabledExtensionNames = &requiredExtensions[0]

	// for ext in requiredExtensions {
	// 	fmt.printf("ext: %s\n", ext)
	// }

	vulkan.load_proc_addresses(rawptr(glfw.GetInstanceProcAddress))
	assert(vulkan.CreateInstance != nil, "CreateInstance is nil")

	assert(&vkInstanceInfo != nil, "instance info is null")
	result := vulkan.CreateInstance(&vkInstanceInfo, nil, &vkInstance)

	if result != vulkan.Result.SUCCESS {
		fmt.printf("failed to create vulkan instance %s\n", result)
		panic("")
	}

	// extensionCount: u32 = 0
	// vulkan.EnumerateInstanceExtensionProperties(nil, &extensionCount, nil)
	// extensions := make_slice([]vulkan.ExtensionProperties, int(extensionCount))
	// defer delete(extensions)
	// vulkan.EnumerateInstanceExtensionProperties(nil, &extensionCount, &extensions[0])
	//
	// for extension in extensions {
	// 	fmt.printf("extension: %s\n", extension.extensionName)
	// }
}


main :: proc() {
	glfw.SetErrorCallback(error_callback)

	if !glfw.Init() {
		fmt.println("Failed to initialize GLFW")
		return
	}
	defer glfw.Terminate()

	if !glfw.VulkanSupported() {
		fmt.println("Vulkan is not supported")
		return
	}

	glfw.WindowHint(glfw.CLIENT_API, glfw.NO_API)
	window := glfw.CreateWindow(800, 700, "Triangle", nil, nil)

	if window == nil {
		fmt.println("Failed to create GLFW window")
		return
	}
	defer glfw.DestroyWindow(window)

	createVkInstance()
	defer vulkan.DestroyInstance(vkInstance, nil)

	glfw.SetKeyCallback(window, key_callback)
	// glfw.MakeContextCurrent(window)
	// glfw.SwapInterval(1)

	for !glfw.WindowShouldClose(window) {
		glfw.PollEvents()
		// glfw.SwapBuffers(window)
	}

}
