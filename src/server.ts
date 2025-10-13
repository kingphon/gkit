#!/usr/bin/env node

import express from 'express';
import cors from 'cors';
import { GkitCommands, executeGkit, ToolToGkitCommandMap } from './core.js';

const app = express();
const port = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json());

// Dynamically create API routes from the GkitCommands array
GkitCommands.forEach(tool => {
  const command = ToolToGkitCommandMap[tool.name];
  if (!command) {
    console.warn(`No gkit command mapping found for tool: ${tool.name}`);
    return;
  }

  const endpoint = `/api/${tool.name.replace(/_/g, '-')}`;
  
  app.post(endpoint, async (req, res) => {
    // Extract arguments from the request body based on the tool's input schema
    const args: string[] = [];
    const requiredParams = (tool.inputSchema.required || []) as string[];
    
    for (const param of requiredParams) {
      if (req.body[param] === undefined) {
        return res.status(400).json({ success: false, error: `Parameter '${param}' is required` });
      }
    }

    // A simple, ordered way to pass arguments. Note: This assumes a consistent order.
    // For more complex scenarios, a more robust argument mapping would be needed.
    const paramOrder = Object.keys(tool.inputSchema.properties || {});
    paramOrder.forEach(param => {
      if (req.body[param] !== undefined) {
        args.push(req.body[param]);
      }
    });

    console.log(`Executing command '${command}' with args:`, args);
    const result = await executeGkit(command, args);
    res.json(result);
  });

  console.log(`✅ Registered API endpoint: POST ${endpoint}`);
});

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// Start server
app.listen(port, () => {
  console.log(`🚀 GKit MCP Server running on port ${port}`);
  console.log(`📡 Health check: http://localhost:${port}/health`);
});
