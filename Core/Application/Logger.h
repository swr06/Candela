#pragma once

#include <iostream>

namespace Lumen
{
	namespace Logger
	{
		void Log(const std::string& txt);
		void LogToFile(const std::string& txt);
	}
}