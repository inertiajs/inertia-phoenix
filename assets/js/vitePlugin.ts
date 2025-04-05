import { IncomingMessage, ServerResponse } from 'http'
import { Connect, Plugin } from 'vite'

interface ExtendedRequest extends Connect.IncomingMessage {
  body?: Record<string, unknown>
}

const jsonResponse = (res: ServerResponse<IncomingMessage>, statusCode: number, data: unknown) => {
  res.statusCode = statusCode
  res.setHeader('Content-Type', 'application/json')
  res.end(JSON.stringify(data))
}

const jsonMiddleware = (req: ExtendedRequest, res: ServerResponse<IncomingMessage>, next: () => Promise<void>) => {
  let data = ''
  req.on('data', (chunk) => (data += chunk))
  req.on('end', () => {
    try {
      req.body = JSON.parse(data)
      next()
    } catch {
      jsonResponse(res, 400, { error: 'Invalid JSON' })
    }
  })
  req.on('error', () => {
    jsonResponse(res, 500, { error: 'Internal Server Error' })
  })
}

const SSR_DEV_SERVER_PATH = '/ssr_render'
export default function inertiaPhoenixPlugin({ entrypoint }: { entrypoint: string }): Plugin {
  return {
    name: 'inertia-phoenix',
    configureServer(server) {
      if (!entrypoint) {
        throw new Error(
          `[inertia-phoenix] Missing required \`entrypoint\` in plugin options.

Please pass the path to your SSR entry file.

Example:
  inertiaPhoenixPlugin({ entrypoint: './js/ssr.{jsx|tsx}' })`
        )
      }

      // exit cleanly with Phoenix (dev only)
      process.stdin.on('close', () => process.exit(0))
      process.stdin.resume()

      server.middlewares.use((req: ExtendedRequest, res, next) => {
        if (req.method === 'POST' && req.url?.split('?', 1)[0] === SSR_DEV_SERVER_PATH) {
          jsonMiddleware(req, res, async () => {
            try {
              const { render } = await server.ssrLoadModule(entrypoint)
              const html = await render(req.body)

              jsonResponse(res, 200, {
                head: [], // optional preload links
                body: html,
              })
            } catch (e) {
              if (e instanceof Error) {
                server.ssrFixStacktrace(e)

                jsonResponse(res, 500, {
                  error: {
                    message: e.message,
                    stack: e.stack,
                  },
                })
              } else {
                jsonResponse(res, 500, {
                  error: {
                    message: 'Unknown error',
                    detail: e,
                  },
                })
              }
            }
          })
        } else {
          next()
        }
      })
    },
  }
}
