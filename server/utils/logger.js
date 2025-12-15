const path = require('path');
const fs = require('fs');

// ANSI Escape Codes for "Explosive" Colors
const COLORS = {
    RESET: "\x1b[0m",
    BRIGHT: "\x1b[1m",
    DIM: "\x1b[2m",
    UNDERSCORE: "\x1b[4m",
    BLINK: "\x1b[5m",
    REVERSE: "\x1b[7m",
    HIDDEN: "\x1b[8m",

    FG_BLACK: "\x1b[30m",
    FG_RED: "\x1b[31m",
    FG_GREEN: "\x1b[32m",
    FG_YELLOW: "\x1b[33m",
    FG_BLUE: "\x1b[34m",
    FG_MAGENTA: "\x1b[35m",
    FG_CYAN: "\x1b[36m",
    FG_WHITE: "\x1b[37m",

    BG_BLACK: "\x1b[40m",
    BG_RED: "\x1b[41m",
    BG_GREEN: "\x1b[42m",
    BG_YELLOW: "\x1b[43m",
    BG_BLUE: "\x1b[44m",
    BG_MAGENTA: "\x1b[45m",
    BG_CYAN: "\x1b[46m",
    BG_WHITE: "\x1b[47m"
};

const isDebug = process.env.DEBUG_MODE === 'true';

// Log Directory Setup
const timestampForDir = new Date().toISOString().replace(/[:.]/g, '-').replace('T', '_').replace('Z', '');
const logDir = path.join(__dirname, '../logs', timestampForDir);
const streams = {};

try {
    if (!fs.existsSync(logDir)) {
        fs.mkdirSync(logDir, { recursive: true });
        console.log(`[LOGGER] Session logs: ${logDir}`);
    }

    streams.all = fs.createWriteStream(path.join(logDir, 'all.log'), { flags: 'a' });
    streams.error = fs.createWriteStream(path.join(logDir, 'error.log'), { flags: 'a' });
    streams.http = fs.createWriteStream(path.join(logDir, 'http.log'), { flags: 'a' });
    streams.socket = fs.createWriteStream(path.join(logDir, 'socket.log'), { flags: 'a' });
} catch (e) {
    console.error(`[LOGGER] Failed to create log directory:`, e);
}

const stripColors = (str) => {
    // eslint-disable-next-line no-control-regex
    return str.replace(/\x1b\[[0-9;]*m/g, '');
};

const getTimestamp = () => {
    return new Date().toISOString().replace('T', ' ').replace('Z', '');
};

const writeToFile = (streamName, message) => {
    const cleanMessage = stripColors(message);
    if (streams.all) streams.all.write(cleanMessage + '\n');
    if (streams[streamName] && streamName !== 'all') streams[streamName].write(cleanMessage + '\n');
};

const formatMessage = (level, message, ...args) => {
    const timestamp = getTimestamp();
    let prefix = "";

    switch (level) {
        case 'INFO':
            prefix = `${COLORS.FG_CYAN}[INFO]${COLORS.RESET}`;
            break;
        case 'WARN':
            prefix = `${COLORS.FG_YELLOW}${COLORS.BRIGHT}[WARN]${COLORS.RESET}`;
            break;
        case 'ERROR':
            prefix = `${COLORS.BG_RED}${COLORS.FG_WHITE}${COLORS.BRIGHT}[ERROR]${COLORS.RESET}${COLORS.FG_RED}`;
            break;
        case 'DEBUG':
            prefix = `${COLORS.FG_MAGENTA}[DEBUG]${COLORS.RESET}`;
            break;
        case 'HTTP':
            prefix = `${COLORS.FG_GREEN}[HTTP]${COLORS.RESET}`;
            break;
        case 'SOCKET':
            prefix = `${COLORS.FG_BLUE}[SOCKET]${COLORS.RESET}`;
            break;
        default:
            prefix = `[${level}]`;
    }

    const formattedArgs = args.map(arg =>
        typeof arg === 'object' ? JSON.stringify(arg, null, 2) : arg
    ).join(' ');

    return [`${COLORS.DIM}${timestamp}${COLORS.RESET} ${prefix} ${message} ${formattedArgs}`.trim()];
};

const logger = {
    info: (message, ...args) => {
        const msg = formatMessage('INFO', message, ...args)[0];
        console.log(msg);
        writeToFile('info', msg);
    },
    warn: (message, ...args) => {
        const msg = formatMessage('WARN', message, ...args)[0];
        console.warn(msg);
        writeToFile('warn', msg);
    },
    error: (message, error = '') => {
        const msg = formatMessage('ERROR', message)[0];
        console.error(msg);
        writeToFile('error', msg);

        if (error) {
            const stack = error.stack || error;
            console.error(`${COLORS.FG_RED}${stack}${COLORS.RESET}`);
            writeToFile('error', stripColors(stack));
        }
    },
    debug: (message, ...args) => {
        if (isDebug) {
            const msg = formatMessage('DEBUG', message, ...args)[0];
            console.log(msg);
            writeToFile('debug', msg);
        }
    },
    http: (req, res, next) => {
        const start = Date.now();
        const { method, url, body, query } = req;

        // Log request entry
        if (isDebug) {
            const msg = formatMessage('HTTP', `${COLORS.BRIGHT}${method}${COLORS.RESET} ${url}\nQuery: ${JSON.stringify(query)}\nBody: ${JSON.stringify(body)}`)[0];
            console.log(msg);
            writeToFile('http', msg);
        } else {
            // In non-debug, just log the method and URL
            const msg = formatMessage('HTTP', `${method} ${url}`)[0];
            console.log(msg);
            writeToFile('http', msg);
        }

        // Capture response
        const oldSend = res.send;
        res.send = function (data) {
            res.send = oldSend; // restore
            const duration = Date.now() - start;
            const status = res.statusCode;

            let statusColor = COLORS.FG_GREEN;
            if (status >= 400) statusColor = COLORS.FG_YELLOW;
            if (status >= 500) statusColor = COLORS.FG_RED;

            const msg = formatMessage('HTTP',
                `${method} ${url} ${COLORS.BRIGHT}➜${COLORS.RESET} ${statusColor}${status}${COLORS.RESET} (${duration}ms)`
            )[0];

            console.log(msg);
            writeToFile('http', msg);

            return res.send(data);
        };

        next();
    },
    socket: (socket, next) => {
        // This middleware runs for every incoming event
        socket.onAny((eventName, ...args) => {
            if (isDebug) {
                const msg = formatMessage('SOCKET',
                    `${COLORS.FG_BLUE}Event:${COLORS.RESET} ${COLORS.BRIGHT}${eventName}${COLORS.RESET}\nFrom: ${socket.id}\nData: ${JSON.stringify(args)}`
                )[0];
                console.log(msg);
                writeToFile('socket', msg);
            } else {
                const msg = formatMessage('SOCKET', `${eventName} from ${socket.id}`)[0];
                console.log(msg);
                writeToFile('socket', msg);
            }
        });
        next();
    }
};

module.exports = logger;
