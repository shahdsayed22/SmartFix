import { NextResponse } from 'next/server';
import os from 'os';

/* Returns the machine's real LAN IPv4 address(es) so the /connect QR codes can
   target a phone-reachable host instead of localhost. Virtual adapters
   (WSL, Hyper-V vEthernet, Docker, VPNs) are filtered out by name. */
export async function GET() {
    const VIRTUAL = /(vethernet|wsl|hyper-v|virtualbox|vmware|loopback|default switch|docker|tailscale|zerotier|radmin)/i;
    const isPrivate = (ip) =>
        /^192\.168\./.test(ip) ||
        /^10\./.test(ip) ||
        /^172\.(1[6-9]|2\d|3[01])\./.test(ip);

    const ifaces = os.networkInterfaces();
    const ips = [];
    for (const [name, addrs] of Object.entries(ifaces)) {
        if (VIRTUAL.test(name)) continue;
        for (const a of addrs || []) {
            if (a.family === 'IPv4' && !a.internal && isPrivate(a.address)) {
                // Prefer common Wi-Fi/LAN 192.168.x ranges first.
                if (/^192\.168\./.test(a.address)) ips.unshift(a.address);
                else ips.push(a.address);
            }
        }
    }
    return NextResponse.json({ ips });
}
