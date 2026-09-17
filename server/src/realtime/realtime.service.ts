import { Injectable, OnModuleInit, Logger } from '@nestjs/common';
import { HttpAdapterHost } from '@nestjs/core';

// eslint-disable-next-line @typescript-eslint/no-var-requires
const FayeWebSocket = require('faye-websocket');

@Injectable()
export class RealtimeService implements OnModuleInit {
  private readonly logger = new Logger('RealtimeService');
  private readonly clients = new Set<any>();

  constructor(private readonly httpAdapterHost: HttpAdapterHost) {}

  onModuleInit() {
    const server = this.httpAdapterHost.httpAdapter?.getHttpServer();
    if (!server) {
      this.logger.error('HTTP server instance not available for Realtime WebSocket initialization');
      return;
    }

    server.on('upgrade', (request: any, socket: any, head: any) => {
      if (FayeWebSocket.isWebSocket(request)) {
        const ws = new FayeWebSocket(request, socket, head);
        this.addClient(ws);

        ws.on('message', (event: any) => {
          if (event.data === 'ping') {
            try {
              ws.send('pong');
            } catch (_) {}
          }
        });

        ws.on('close', () => {
          this.removeClient(ws);
        });

        ws.on('error', (err: any) => {
          this.logger.warn(`[REALTIME] WebSocket error: ${err?.message || err}`);
          this.removeClient(ws);
        });
      }
    });

    this.logger.log('⚡ [REALTIME] WebSocket Gateway attached to HTTP server upgrade listener');
  }

  private addClient(ws: any) {
    this.clients.add(ws);
    this.logger.log(`⚡ [REALTIME] Client connected (Total active clients: ${this.clients.size})`);
  }

  private removeClient(ws: any) {
    this.clients.delete(ws);
    this.logger.log(`⚡ [REALTIME] Client disconnected (Total active clients: ${this.clients.size})`);
  }

  /**
   * Broadcasts a realtime event to all connected WebSocket clients.
   * @param event The event category ('sadhana_update', 'accommodation_update', 'appointment_update', 'student_update', 'trip_update', 'event_update', 'announcement_update', 'payment_update')
   * @param action The operation performed ('create', 'update', 'delete', 'register')
   * @param data The payload data
   * @param metadata Optional preacherId or studentId
   */
  emit(
    event: string,
    action: string,
    data: any,
    metadata?: { preacherId?: string; studentId?: string },
  ) {
    if (this.clients.size === 0) return;

    const payload = JSON.stringify({
      event,
      action,
      data,
      preacherId: metadata?.preacherId,
      studentId: metadata?.studentId,
      timestamp: new Date().toISOString(),
    });

    let sentCount = 0;
    for (const ws of this.clients) {
      try {
        ws.send(payload);
        sentCount++;
      } catch (e) {
        this.removeClient(ws);
      }
    }

    this.logger.log(`⚡ [REALTIME] Broadcasted event "${event}:${action}" to ${sentCount} client(s)`);
  }
}
