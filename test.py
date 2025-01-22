import time
import random
import concurrent.futures
import os

def perform_fake_transaction():
    """
    Simulate a fake transaction by performing a mix of CPU-intensive tasks.
    """
    for a in range(100):
        # Mathematical operations
        result = 0
        for i in range(100):
            result += i ** 2 - i ** 3 + i ** 4

        # String manipulations
        s = f"This is a test string.{result}"
        for _ in range(100):
            s = s.replace(" ", "_")
            s = s.upper()
            s = s.lower()
            s = s[::-1]

        # List operations
        lst = [random.randint(0, 1000) for _ in range(1000)]
        lst.sort()
        lst.reverse()
        lst = [x ** 2 for x in lst]
        lst = list(filter(lambda x: x % 2 == 0, lst))

    return result, s, lst

def worker(duration_seconds, end_time):
    count = 0
    while time.time() < end_time:
        perform_fake_transaction()
        count += 1
    return count

def test_single_thread_performance(duration_seconds):
    """
    Test single-threaded performance by running fake transactions for a specified duration.
    
    :param duration_seconds: Duration to run the test in seconds.
    :return: Number of fake transactions per second.
    """
    start_time = time.time()
    end_time = start_time + duration_seconds
    transaction_count = 0

    while time.time() < end_time:
        perform_fake_transaction()
        transaction_count += 1

    elapsed_time = time.time() - start_time
    transactions_per_second = transaction_count / elapsed_time

    return transactions_per_second

def test_parallel_performance(duration_seconds, num_workers):
    """
    Test multi-threaded performance by running fake transactions in parallel for a specified duration.
    
    :param duration_seconds: Duration to run the test in seconds.
    :param num_workers: Number of parallel workers to use.
    :return: Number of fake transactions per second.
    """
    start_time = time.time()
    end_time = start_time + duration_seconds

    with concurrent.futures.ProcessPoolExecutor(max_workers=num_workers) as executor:
        futures = [executor.submit(worker, duration_seconds, end_time) for _ in range(num_workers)]
        results = [f.result() for f in concurrent.futures.as_completed(futures)]
        transaction_count = sum(results)

    elapsed_time = time.time() - start_time
    transactions_per_second = transaction_count / elapsed_time

    return transactions_per_second



def get_cpu_model():
    """Helper function to get CPU model name."""
    try:
        if os.name == 'posix':  # Linux/Unix
            with open('/proc/cpuinfo') as f:
                for line in f:
                    if 'model name' in line:
                        return line.split(':')[1].strip()
        return "CPU Model information unavailable"
    except:
        return "CPU Model information unavailable"

if __name__ == "__main__":
    duration = 60  # Duration to run each test in seconds
    
    # Get system information first
    machine_name = os.uname().nodename
    cpu_cores = os.cpu_count()
    os_info = f"{os.uname().sysname} {os.uname().release}"
    cpu_model = get_cpu_model()
    
    # Run performance tests
    tps_single = test_single_thread_performance(duration)
    tps_parallel = test_parallel_performance(duration, cpu_cores)
    speedup = tps_parallel / tps_single
    
    # Print CSV header and data
    print("Machine;CPU_Cores;OS;CPU_Model;Single_Thread_TPS;Multi_Thread_TPS;Speedup")
    print(f"{machine_name};{cpu_cores};{os_info};{cpu_model};{tps_single:.2f};{tps_parallel:.2f};{speedup:.2f}")
