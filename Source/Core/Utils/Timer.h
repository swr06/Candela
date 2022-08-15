#pragma once

#include <chrono>
#include <string>
#include <sstream>
#include "../Application/Logger.h"

namespace Blocks
{
	class Timer
	{
	public : 

		Timer() {}

		void Start()
		{
			 m_StartTime = std::chrono::high_resolution_clock::now();
			 m_TimerStarted = true;
		}

		float End()
		{
			if (!m_TimerStarted) { throw "Blocks::Timer()::End() called without the timer being started!"; return 0; }

			float total_time;

			m_EndTime = std::chrono::high_resolution_clock::now();
			total_time = std::chrono::duration_cast<std::chrono::microseconds>(m_EndTime - m_StartTime).count();
			total_time /= 1000.0f;

			return total_time;
		}

		~Timer() {}

	private :

		std::chrono::steady_clock::time_point m_StartTime;
		std::chrono::steady_clock::time_point m_EndTime;
		bool m_TimerStarted = false;
	};
}