-- 서버 시작점: 코스를 만들고 스테이지 시스템을 켭니다.
local CourseBuilder = require(script.CourseBuilder)
local StageService = require(script.StageService)

local course = CourseBuilder.build()
StageService.start(course)

print(`✅ 오비 코스 준비 완료! (스테이지 {#course.checkpoints}개)`)
