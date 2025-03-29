import { IncomingMessage, ServerResponse } from 'http'
import { Connect, ModuleNode, Plugin } from 'vite'

interface PluginOptions {
  path?: string // defaults to /ssr_render
  entrypoint?: string // path to user’s ssr.js
}

interface ExtendedRequest extends Connect.IncomingMessage {
  body?: Record<string, unknown>
}

const jsonResponse = (res: ServerResponse<IncomingMessage>, statusCode: number, data: unknown) => {
  res.statusCode = statusCode
  res.setHeader('Content-Type', 'application/json')
  res.end(JSON.stringify(data))
}

// Parses JSON body into req.body
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

const hotUpdateType = (path: string): 'css-update' | 'js-update' | null => {
  if (path.endsWith('.css')) return 'css-update'
  if (path.endsWith('.js')) return 'js-update'
  return null
}

export default function inertiaPhoenixPlugin(opts: PluginOptions = {}): Plugin {
  return {
    name: 'inertia-phoenix',

    handleHotUpdate({ file, modules, server, timestamp }) {
      if (file.match(/\.(heex|ex)$/)) {
        const invalidatedModules = new Set<ModuleNode>()
        for (const mod of modules) {
          server.moduleGraph.invalidateModule(mod, invalidatedModules, timestamp, true)
        }

        const updates = Array.from(invalidatedModules).flatMap((m) => {
          if (!m.file) return []
          const type = hotUpdateType(m.file)
          if (!type) return []
          return [
            {
              type,
              path: m.url,
              acceptedPath: m.url,
              timestamp,
            },
          ]
        })

        server.ws.send({ type: 'update', updates })
        return [] // we handled the update
      }
    },

    configureServer(server) {
      const path = opts.path || '/ssr_render'
      const entrypoint = opts.entrypoint
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
        if (req.method === 'POST' && req.url?.split('?', 1)[0] === path) {
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
