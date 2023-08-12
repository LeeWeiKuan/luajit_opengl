-- 纯lua脚本的opengl应用，利用luajit的ffi功能实现

local ffi = require "ffi"

ffi.cdef [[
// 错误响应函数
typedef void(* GLFWerrorfun) (int error_code, const char *description);
GLFWerrorfun glfwSetErrorCallback(GLFWerrorfun callback);

// 初始化、结束函数
int glfwInit();
void glfwTerminate();

// contex设置
void glfwWindowHint(int hint, int value);

// 创建窗口
typedef struct GLFWwindow GLFWwindow;
typedef struct GLFWmonitor GLFWmonitor;
GLFWwindow* glfwCreateWindow(int width, int height, const char *title, GLFWmonitor *monitor, GLFWwindow *share);
void glfwSetWindowShouldClose(GLFWwindow *window, int value);

// 按键响应函数类型, 绑定案件响应函数
typedef void(* GLFWkeyfun) (GLFWwindow *window, int key, int scancode, int action, int mods);
GLFWkeyfun glfwSetKeyCallback(GLFWwindow *window, GLFWkeyfun callback);

typedef void (* GLFWwindowfocusfun)(GLFWwindow*,int);
GLFWwindowfocusfun glfwSetWindowFocusCallback(GLFWwindow* window, GLFWwindowfocusfun cbfun);

// 事件处理函数
typedef void *HWND;
HWND GetActiveWindow();
typedef unsigned int UINT;
typedef long LPARAM;
typedef unsigned int WPARAM;
bool PostMessageA(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam);

// OpenGL上下文
void glfwMakeContextCurrent(GLFWwindow* window);

// 设置OPENGL加载函数
typedef void (*GLFWglproc)(void);
GLFWglproc glfwGetProcAddress(const char* procname);

// 设置垂直同步
void glfwSwapInterval(int interval);

// 主循环
int glfwWindowShouldClose(GLFWwindow* window);
void glfwSwapBuffers(GLFWwindow* window);
void glfwPollEvents(void);

// data
typedef struct
{
    float r, g, b;
} Vertex;

// gl
typedef int GLint;
typedef int GLsizei;
typedef int GLsizeiptr;
typedef unsigned int GLuint;
typedef unsigned int GLenum;
typedef unsigned int GLbitfield;
typedef unsigned char GLboolean;
typedef char GLchar;
typedef signed char GLbyte;
typedef short GLshort;
typedef unsigned char GLubyte;
typedef unsigned short GLushort;
typedef unsigned long GLulong;
typedef float GLfloat;
typedef float GLclampf;
typedef double GLdouble;
typedef double GLclampd;
typedef void GLvoid;
]]

-- ============================================================================
-- load glfw.dll
local glfw = ffi.load("glfw")

-- ============================================================================
-- 具体运行
-- 1. 创建error callback function
local error_cb_func = function(error_code, description)
	print("[error] code:", error_code)
	print("[error] description: ", ffi.string(description))
end
local error_cb_pointer = ffi.cast("GLFWerrorfun", error_cb_func)

-- 2. 绑定错误处理函数
glfw.glfwSetErrorCallback(error_cb_pointer)

-- 3. 初始化
local init_result = glfw.glfwInit()
if init_result ~= 1 then
	print("glfwInit error, exit!")
	return
end

-- 4. 设置context版本
local enum = {
	WM_KEYDOWN = 0x0100,

	GLFW_CONTEXT_VERSION_MAJOR = 0x00022002,
	GLFW_CONTEXT_VERSION_MINOR = 0x00022003,
	GLFW_KEY_ESCAPE = 256,
	GLFW_PRESS = 1,
	GLFW_TRUE = 1,

	GL_FALSE = 0,
	GL_FLOAT = 0x1406,
	GL_ARRAY_BUFFER = 0x8892,
	GL_ELEMENT_ARRAY_BUFFER = 0x8893,
	GL_STATIC_DRAW = 0x88E4,
	GL_TRIANGLES = 0x0004,
	GL_UNSIGNED_INT = 0x1405,
	GL_FRAGMENT_SHADER = 0x8B30,
	GL_VERTEX_SHADER = 0x8B31,
	GL_COMPILE_STATUS = 0x8B81,
	GL_LINK_STATUS = 0x8B82,
	GL_COLOR_BUFFER_BIT  = 0x00004000,
}
glfw.glfwWindowHint(enum.GLFW_CONTEXT_VERSION_MAJOR, 3)
glfw.glfwWindowHint(enum.GLFW_CONTEXT_VERSION_MINOR, 3)
print("set context done!")

-- 5. 创建窗口
local window = glfw.glfwCreateWindow(640, 480, "PureLuaGL", nil, nil)
local window_result = tonumber(ffi.cast("int", window))
if window_result ~= 0 then
	print("The window is created!")
else
	glfw.glfwTerminate()
	print("Error occures when creating window.")
	return
end

-- 6. 绑定按钮
-- 按键响应函数
local key_callback_func = function(window, key, scancode, action, mods)
	if key == enum.GLFW_KEY_ESCAPE and action == enum.GLFW_PRESS then
		print("close")
		glfw.glfwSetWindowShouldClose(window, enum.GLFW_TRUE)
	end
end
local key_callback_pointer = ffi.cast("GLFWkeyfun", key_callback_func)
glfw.glfwSetKeyCallback(window, key_callback_pointer)
-- ！！这里很奇怪，需要按下按钮，触发一次回调，然后后面才不会报错。
-- 不然会报 PANIC: unprotected error in call to Lua API (bad callback)
-- 直接点击窗口会出问题
-- ※※ 发送一个消息给窗口触发一次调用
local hwnd = ffi.C.GetActiveWindow()
ffi.C.PostMessageA(hwnd, enum.WM_KEYDOWN, 1, 0) -- 随便发一个按键事件给窗口，防止callback报错。

-- 7. 创建opengl上下文
glfw.glfwMakeContextCurrent(window)

-- 8. 设置
-- gladLoadGL(glfw.glfwGetProcAddress)
local gl = {}

local init_gl_function = function(gl_function_name, declaration)
	local function_pointer = glfw.glfwGetProcAddress(gl_function_name)
	gl[gl_function_name] = ffi.cast(declaration, function_pointer)
	return gl[gl_function_name]
end

local gl_function_declarations = {
	glGenBuffers = "void (*)(int, int*)",
	glBindBuffer = "void (*)(int, unsigned int)",
	glBufferData = "void (*)(GLenum, GLsizeiptr, const void *, GLenum)",
	glCreateShader = "GLuint (*)(GLenum shaderType)",
	glShaderSource = "void (*)(GLuint shader, GLsizei count, const GLchar **string, const GLint *length)",
	glCompileShader = "void (*)(GLuint shader)",
	glGetShaderiv = "void (*)(GLuint shader, GLenum pname, GLint* param)",
	glCreateProgram = "GLuint (*)(void)",
	glAttachShader = "void (*)(GLuint program, GLuint shader)",
	glLinkProgram = "void (*)(GLuint program)",
	glGetProgramiv = "void (*)(GLuint program, GLenum pname, GLint* param)",
	glDeleteShader = "void (*)(GLuint shader)",
	glGenVertexArrays = "void (*)(GLsizei n, const GLuint* arrays)",
	glBindVertexArray = "void (*)(GLuint array)",
	glEnableVertexAttribArray = "void (*)(GLuint)",
	glVertexAttribPointer = "void (*)(GLuint index, GLint size, GLenum type, GLboolean normalized, GLsizei stride, const GLvoid* pointer)",
	glClearColor = "void (*)(GLfloat red, GLfloat green, GLfloat blue, GLfloat alpha)",
	glClear = "void (*)(GLbitfield mask)",
	glUseProgram = "void (*)(GLuint program)",
	glDrawElements = "void (*)(GLenum mode, GLsizei count, GLenum type, const void * indices)"
}

for function_name, function_declaration in pairs(gl_function_declarations) do
	init_gl_function(function_name, function_declaration)
end

-- 9. 设置垂直同步
glfw.glfwSwapInterval(1);

-- 10. OpenGL 设置buffer和着色器
-- 顶点着色器
local vertex_shader_text = [[
#version 330 core
layout (location = 0) in vec3 aPos;
void main()
{
   gl_Position = vec4(aPos.x, aPos.y, aPos.z, 1.0);
}
]]
local vertex_shader_address_pointer = ffi.new("char*[1]")
local vertex_shader_char_array = ffi.new("char[?]", #vertex_shader_text+1, vertex_shader_text)
vertex_shader_char_array[#vertex_shader_text] = 0
vertex_shader_address_pointer[0] = vertex_shader_char_array
-- 编译顶点着色器
local vertex_shader = gl.glCreateShader(enum.GL_VERTEX_SHADER)
gl.glShaderSource(vertex_shader, 1, ffi.cast("const char **", vertex_shader_address_pointer), nil)
gl.glCompileShader(vertex_shader)
-- 检查是否编译成功
local is_success = ffi.new("int[1]")
gl.glGetShaderiv(vertex_shader, enum.GL_COMPILE_STATUS, is_success)
print("vertex_shader is_success", is_success[0])

-- 片元着色器
local fragment_shader_text = [[
#version 330 core
out vec4 FragColor;
void main()
{
    FragColor = vec4(1.0f, 0.5f, 0.2f, 1.0f);
}
]]
local fragment_shader_char_array = ffi.new("char[?]", #fragment_shader_text+1, fragment_shader_text)
fragment_shader_char_array[#fragment_shader_text] = 0
local fragment_shader_address_pointer = ffi.new("char*[1]")
fragment_shader_address_pointer[0] = fragment_shader_char_array
local fragment_shader = gl.glCreateShader(enum.GL_FRAGMENT_SHADER)
gl.glShaderSource(fragment_shader, 1, ffi.cast("const char **", fragment_shader_address_pointer), nil)
gl.glCompileShader(fragment_shader)
-- 检查是否编译成功
gl.glGetShaderiv(fragment_shader, enum.GL_COMPILE_STATUS, is_success)
print("fragment_shader is_success", is_success[0])

-- 链接着色器
local shaderProgram = gl.glCreateProgram()
gl.glAttachShader(shaderProgram, vertex_shader)
gl.glAttachShader(shaderProgram, fragment_shader)
gl.glLinkProgram(shaderProgram)
-- 检查链接情况
gl.glGetProgramiv(shaderProgram, enum.GL_LINK_STATUS, is_success);
print("shader program is_success", is_success[0])
-- 删除shader
gl.glDeleteShader(vertex_shader)
gl.glDeleteShader(fragment_shader)

-- 11. 准备顶点数据
local vertices_data = {
	[0] = {0.5, 0.5, 0.0},
	[1] = {0.5, -0.5, 0.0},
	[2] = {-0.5, -0.5, 0.0},
	[3] = {-0.5, 0.5, 0.0}
}
local vertices = ffi.new("Vertex[4]", vertices_data)

local indices_data = {
	0, 1, 3,
	1, 2, 3
}
local indices = ffi.new("unsigned int[6]", indices_data)

-- 准备各种缓冲buffer
-- 1. 顶点信息数据对象（（这个并不是缓存，不会保存顶点数据，而是顶点数组的各种信息）
local vao_pointer = ffi.new("unsigned int[1]")
gl.glGenVertexArrays(1, vao_pointer)
local vao_value = vao_pointer[0]
-- 2. 顶点数据buffer
local vbo_pointer = ffi.new("unsigned int[1]")
gl.glGenBuffers(1, vbo_pointer)
local vbo_value = vbo_pointer[0]
-- 3. 顶点索引buffer
local ebo_pointer = ffi.new("unsigned int[1]")
gl.glGenBuffers(1, ebo_pointer)
local ebo_value = ebo_pointer[0]

-- 使用这个顶点数组对象、缓冲
gl.glBindVertexArray(vao_value)

gl.glBindBuffer(enum.GL_ARRAY_BUFFER, vbo_value)
gl.glBufferData(enum.GL_ARRAY_BUFFER, 4 * ffi.sizeof("Vertex"), vertices, enum.GL_STATIC_DRAW)  -- 将数据复制到array_buffer中

gl.glBindBuffer(enum.GL_ELEMENT_ARRAY_BUFFER, ebo_value)
gl.glBufferData(enum.GL_ELEMENT_ARRAY_BUFFER, 6 * ffi.sizeof("unsigned int"), indices, enum.GL_STATIC_DRAW)

gl.glVertexAttribPointer(0, 3, enum.GL_FLOAT, enum.GL_FALSE, 3*ffi.sizeof("float"), nil)
gl.glEnableVertexAttribArray(0)


-- 进入循环
while glfw.glfwWindowShouldClose(window)~= 1 do
	g_frame_idx = (g_frame_idx or 0) + 1
	-- print("frame_idx", frame_idx)
	-- print(string.format("FPS: %0.2f , total frame: %d", get_fps(), g_frame_idx))

	gl.glClearColor(0.2, 0.3, 0.3, 1.0)
	gl.glClear(enum.GL_COLOR_BUFFER_BIT)

	gl.glUseProgram(shaderProgram)
	gl.glBindVertexArray(vao_value)
	gl.glDrawElements(enum.GL_TRIANGLES, 6, enum.GL_UNSIGNED_INT, nil)

	glfw.glfwSwapBuffers(window)
	glfw.glfwPollEvents()
end

glfw.glfwTerminate()