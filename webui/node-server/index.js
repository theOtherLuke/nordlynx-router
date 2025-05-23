// MIT License
//
// Copyright (c) 2025 nodaddyno
//
// Permission is hereby granted, free of charge, to any person obtaining a
// copy of this software and associated documentation files (the
// "Software"), to deal in the Software without restriction, including
// without limitation the rights to use, copy, modify, merge, publish,
// distribute, sublicense, and/or sell copies of the Software, and to
// permit persons to whom the Software is furnished to do so, subject to
// the following conditions:
//
// The above copyright notice and this permission notice shall be included
// in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
// OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
// IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
// CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
// TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
// SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

import fs from 'fs';
import https from 'https';
import http from 'http';
import express from 'express';
import { exec } from 'child_process';
import path from 'path';
import { fileURLToPath } from 'url';
import { WebSocketServer } from 'ws';
import os from 'os';

const thishostname = os.hostname();
console.log(thishostname);

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const app = express();

// SSL certs
const credentials = {
  key: fs.readFileSync('./ssl/key.pem'),
  cert: fs.readFileSync('./ssl/cert.pem'),
};

// Redirect HTTP to HTTPS
http.createServer((req, res) => {
  res.writeHead(301, { Location: `https://${req.headers.host}${req.url}` });
  res.end();
}).listen(8080);

// HTTPS server
const httpsServer = https.createServer(credentials, app);

// WebSocket
const wss = new WebSocketServer({ server: httpsServer });

// Middleware
app.use(express.static(path.join(__dirname, 'public')));
app.use(express.urlencoded({ extended: true }));
app.set('view engine', 'ejs');

// Command definitions
const pageCommands = {
  status: './scripts/get-nord.sh status',
  settings: './scripts/get-nord.sh settings',
  account: './scripts/get-nord.sh -o account',
  about: './scripts/about.sh',
  login: './scripts/login.sh',
  settingChange: './scripts/toggle-setting.sh ${key}'
};

// Polling and active views logic
const pollingIntervals = {};

// Run command helper
const runCommand = (cmd, cb) => {
  exec(cmd, (err, stdout, stderr) => {
    if (err) cb(stderr || err, null);
    else {
      const output = stdout.trim();
      try {
        const json = JSON.parse(output);
        cb(null, json);
      } catch {
        cb(null, output);
      }
    }
  });
};

// WebSocket command streaming
wss.on('connection', (ws, req) => {
    const url = new URL(req.url, `https://${req.headers.host}`);
    const page = url.searchParams.get('path');
  
    // Only set up polling for status and settings pages
    if (page === 'status' || page === 'settings') {
      if (!pollingIntervals[page]) {
        // Start polling at an interval of 5 seconds
        pollingIntervals[page] = setInterval(() => {
          runCommand(pageCommands[page], (err, result) => {
            if (!err) {
              ws.send(err ? `Error: ${err}` : JSON.stringify(result));
            }
          });
        }, 10000);  // Poll every 5 seconds
  
        // Send initial data for the page only after the interval is set
        setTimeout(() => {
          runCommand(pageCommands[page], (err, output) => {
            ws.send(err ? `Error: ${err}` : (typeof output === 'object' ? JSON.stringify(output) : output));
          });
        }, 5000);  // Wait for 5 seconds before sending initial data
      }
    }
  
    // Close the WebSocket and stop polling on disconnect
    ws.on('close', () => {
      if (pollingIntervals[page]) {
        clearInterval(pollingIntervals[page]);
        delete pollingIntervals[page];
      }
    });
  });

// Render page helper
const renderPage = (page) => (req, res) => {
  runCommand(pageCommands[page], (err, output) => {
//    const hostname = req.hostname;
    res.render('index', { page, output, message: null, hostname: `${thishostname}` });
  });
};

// Routes
app.get('/', (req, res) => res.redirect('/status'));
app.get('/status', renderPage('status'));
// app.get('/settings', renderPage('settings'));
app.get('/account', renderPage('account'));
app.get('/about', renderPage('about'));
app.get('/login', renderPage('login'));

// Settings action
app.get('/settings', (req, res) => {
    const { key } = req.query;
    if (key) console.log(`Toggling setting: ${key}`);
    if (key) {
      // Run command with the key or handle the key as needed
      const command = pageCommands.settingChange.replace('${key}', key);
      runCommand(command, () => res.redirect('/settings'));
    } else {
      runCommand(pageCommands['settings'], (err, output) => {
        res.render('index', { page: 'settings', output, message: null, hostname: `${thishostname}` });
      });
    }
  });

// Login POST
app.post('/login', (req, res) => {
  const { response } = req.body;
  runCommand(`./validate-token.sh ${response}`, (err, result) => {
    const success = result === 'Success';
    const message = success ? '✅ Login Successful' : '❌ Login Failed';
    res.render('index', {
      page: 'login',
      output: '/run-auth-link',
      message,
    });
  });
});

httpsServer.listen(1776, () => console.log('HTTPS server running on port 1776'));
