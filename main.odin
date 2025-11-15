package main

import "vendor:glfw"
import "vendor:vulkan"
import "core:fmt"
import "core:c"
import "base:runtime"

error_callback :: proc "c" (code: i32, desc: cstring) {
	context = runtime.default_context()
	fmt.println(desc, code)
}

key_callback :: proc "c" (window: glfw.WindowHandle, key, scancode, action, mods: i32) {
	if (key == glfw.KEY_ESCAPE && action == glfw.PRESS) || (key == glfw.KEY_Q && action == glfw.PRESS) {
		glfw.SetWindowShouldClose(window, glfw.TRUE)
	}
}

main :: proc() {
  if !glfw.Init() {
		fmt.println("Failed to initialize GLFW")
		return
	}
  defer glfw.Terminate()

  glfw.WindowHint(glfw.CLIENT_API, glfw.NO_API)
  window := glfw.CreateWindow(800, 700, "Vulkan Windows", nil, nil)

  if window == nil {
		fmt.println("Failed to create GLFW window")
		return
	}
  defer glfw.DestroyWindow(window)

  glfw.SetKeyCallback(window, key_callback)
  glfw.MakeContextCurrent(window)
  glfw.SwapInterval(1)

  for !glfw.WindowShouldClose(window) {
    glfw.PollEvents()
    glfw.SwapBuffers(window)
  }

}
