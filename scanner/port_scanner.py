"""Port scanner for network security assessment"""

import socket
import concurrent.futures
from typing import List, Dict, Optional


class PortScanner:
    """Scan network hosts for open ports"""

    def __init__(self, timeout: float = 1.0, max_workers: int = 100):
        self.timeout = timeout
        self.max_workers = max_workers
        self.common_ports = {
            21: 'FTP',
            22: 'SSH',
            23: 'Telnet',
            25: 'SMTP',
            53: 'DNS',
            80: 'HTTP',
            110: 'POP3',
            143: 'IMAP',
            443: 'HTTPS',
            445: 'SMB',
            3306: 'MySQL',
            3389: 'RDP',
            5432: 'PostgreSQL',
            5984: 'CouchDB',
            6379: 'Redis',
            8080: 'HTTP-Alt',
            8443: 'HTTPS-Alt',
            9200: 'Elasticsearch',
            27017: 'MongoDB'
        }

    def _scan_port(self, host: str, port: int) -> Optional[Dict]:
        """Scan single port"""
        sock = None
        try:
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.settimeout(self.timeout)
            result = sock.connect_ex((host, port))

            if result == 0:
                banner = self._grab_banner(sock)
                service = self.common_ports.get(port, 'Unknown')
                severity = self._assess_severity(port, service)

                return {
                    'type': 'open_port',
                    'severity': severity,
                    'location': f"{host}:{port}",
                    'service': service,
                    'banner': banner,
                    'description': f"Open port detected: {service}",
                    'remediation': self._get_remediation(port, service)
                }

            return None
        except socket.error:
            return None
        except Exception:
            return None
        finally:
            if sock:
                try:
                    sock.close()
                except Exception:
                    pass

    def _grab_banner(self, sock: socket.socket) -> str:
        """Attempt to grab service banner"""
        try:
            sock.send(b'HEAD / HTTP/1.0\r\n\r\n')
            sock.settimeout(0.5)
            banner = sock.recv(1024).decode('utf-8', errors='ignore')
            return banner[:200] if banner else ''
        except Exception:
            return ''

    def _assess_severity(self, port: int, service: str) -> str:
        """Assess severity based on port/service"""
        critical_ports = [23, 445, 3389]  # Telnet, SMB, RDP
        high_ports = [21, 6379, 27017, 9200, 5984]  # FTP, Redis, MongoDB, Elasticsearch, CouchDB

        if port in critical_ports:
            return 'CRITICAL'
        elif port in high_ports:
            return 'HIGH'
        elif service == 'Unknown':
            return 'MEDIUM'
        else:
            return 'LOW'

    def _get_remediation(self, port: int, service: str) -> str:
        """Get remediation advice"""
        remediations = {
            21: 'Disable FTP or use SFTP instead',
            23: 'Disable Telnet immediately - use SSH',
            445: 'Restrict SMB access to internal networks only',
            3389: 'Use VPN for RDP access, enable NLA',
            6379: 'Bind Redis to localhost, enable authentication',
            27017: 'Enable MongoDB authentication, bind to localhost',
            9200: 'Enable Elasticsearch authentication, restrict network access',
            5984: 'Enable CouchDB authentication, bind to localhost'
        }
        return remediations.get(port, f'Review if {service} exposure is necessary')

    def scan(self, host: str, ports: List[int] = None) -> List[Dict]:
        """Scan host for open ports"""
        if ports is None:
            ports = list(self.common_ports.keys())

        findings = []

        with concurrent.futures.ThreadPoolExecutor(max_workers=self.max_workers) as executor:
            futures = {
                executor.submit(self._scan_port, host, port): port
                for port in ports
            }

            for future in concurrent.futures.as_completed(futures):
                result = future.result()
                if result:
                    findings.append(result)

        return findings

    def scan_range(self, host: str, start_port: int, end_port: int) -> List[Dict]:
        """Scan port range"""
        ports = list(range(start_port, end_port + 1))
        return self.scan(host, ports)
