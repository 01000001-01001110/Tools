import requests
import socket
import time
import logging
import matplotlib.pyplot as plt
from concurrent.futures import ThreadPoolExecutor

# Setup logging
logging.basicConfig(filename='response_log.txt', level=logging.INFO, format='%(asctime)s %(message)s')

# Function to ensure the URL has a scheme
def ensure_scheme(url):
    if not url.startswith(('http://', 'https://')):
        return 'http://' + url
    return url

# Function to resolve the URI to an IP address
def resolve_uri_to_ip(uri):
    try:
        hostname = socket.gethostbyname(uri)
        ip_addresses = socket.gethostbyname_ex(hostname)[2]
        logging.info(f"Resolved IP addresses for {uri}: {ip_addresses}")
        return ip_addresses
    except Exception as e:
        logging.error(f"Error: Unable to resolve IP address for {uri}: {e}")
        return []

# Function to get HTTP response details with logging
def get_http_response(url, ip, request_number):
    url_with_scheme = ensure_scheme(url)
    try:
        start = time.time()
        response = requests.get(url_with_scheme, timeout=10)
        end = time.time()
        time_taken = (end - start) * 1000  # Convert to milliseconds
        result = {
            'RequestNumber': request_number,
            'Url': url,
            'IpAddress': ip,
            'StatusCode': response.status_code,
            'ResponseTimeMs': time_taken,
            'StatusDescription': response.reason,
            'Timestamp': start
        }
        logging.info(f"Request #{request_number} to {url} with IP {ip} completed in {time_taken:.2f} ms with status code {response.status_code} at {start}")
        return result
    except Exception as e:
        result = {
            'RequestNumber': request_number,
            'Url': url,
            'IpAddress': ip,
            'StatusCode': 'Failed',
            'ResponseTimeMs': 'N/A',
            'StatusDescription': str(e),
            'Timestamp': time.time()
        }
        logging.error(f"Request #{request_number} to {url} with IP {ip} failed: {e} at {result['Timestamp']}")
        return result

# Function to create a line chart
def create_line_chart(data, title="Response Times", x_label="Request Number", y_label="Response Time (ms)"):
    plt.figure(figsize=(10, 6))
    plt.plot(range(1, len(data) + 1), data, marker='o')
    plt.title(title)
    plt.xlabel(x_label)
    plt.ylabel(y_label)
    plt.grid(True)
    plt.show()

# Main function to perform the test
def test_uri_performance(uri, total_requests=10, max_jobs=3):
    # Resolve IP addresses for the URI
    ip_addresses = resolve_uri_to_ip(uri)
    if not ip_addresses:
        print("Failed to resolve IP addresses. Exiting.")
        return

    # Store response times
    response_times = []

    # Create a thread pool for concurrent requests
    with ThreadPoolExecutor(max_workers=max_jobs) as executor:
        futures = []
        for i in range(1, total_requests + 1):
            ip = ip_addresses[i % len(ip_addresses)]
            futures.append(executor.submit(get_http_response, uri, ip, i))
        
        for future in futures:
            result = future.result()
            if result['ResponseTimeMs'] != 'N/A':
                response_times.append(result['ResponseTimeMs'])
            print(result)

    # Create and show the line chart
    create_line_chart(response_times, title=f"Response Times for {uri}")

# Example usage
test_uri_performance('www.powershellgallery.com', total_requests=10, max_jobs=3)
