#pragma once 

#include <iostream>

#include <thread>

#include <mutex>
#include <condition_variable>

#include <functional>

#include <queue>

namespace Candela {

	template <typename T>
	class ThreadPool {

	public :

		void StartPool(); 
		void AddTask(const T& Task);
		void StopPool();
		bool PoolIsBusy();

	private :

		void ThreadLoop();

		bool m_ShouldTerminate = false;

		std::mutex m_QueueMutex;
		std::condition_variable m_MutexCondition;
		std::vector<std::thread> m_Threads;
		std::queue<std::function<T>> m_TaskQueue;
	};

	template <typename T>
	void ThreadPool<T>::StartPool()
	{
		int ThreadCount = std::thread::hardware_concurrency(); // Max # of threads the system supports
		m_Threads.resize(ThreadCount);

		for (uint32_t i = 0; i < ThreadCount; i++) {
			m_Threads.at(i) = std::thread(ThreadLoop);
		}
	}

	template <typename T>
	void ThreadPool<T>::AddTask(const T& Task)
	{
		std::unique_lock<std::mutex> Lock(m_QueueMutex);
		m_TaskQueue.push(Task);
		m_MutexCondition.notify_one();
	}

	template <typename T>
	void ThreadPool<T>::StopPool()
	{
		{
			std::unique_lock<std::mutex> Lock(m_QueueMutex);
			m_ShouldTerminate = true;
		}

		m_MutexCondition.notify_all();

		// Wait for thread group to finish
		for (std::thread& active_thread : m_Threads)
		{
			active_thread.join();
		}

		m_Threads.clear();
	}

	template <typename T>
	bool ThreadPool<T>::PoolIsBusy()
	{
		bool poolbusy;

		std::unique_lock<std::mutex> lock(m_QueueMutex);
		poolbusy = m_TaskQueue.empty();
		lock.unlock();

		return poolbusy;
	}

	template <typename T>
	void ThreadPool<T>::ThreadLoop()
	{
		while (true) {

			T Task;

			{
				std::unique_lock<std::mutex> Lock(m_QueueMutex);

				m_MutexCondition.wait(Lock, [this] {
					return !m_TaskQueue.empty() || m_ShouldTerminate;
					});

				if (m_ShouldTerminate) {
					return;
				}

				Task = m_TaskQueue.front();
				m_TaskQueue.pop();
			}

			Task();
		}
	}

}