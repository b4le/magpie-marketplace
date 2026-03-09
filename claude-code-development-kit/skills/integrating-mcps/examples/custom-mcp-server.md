# Custom MCP Server Example

## Scenario

You want to create a custom MCP server to expose your internal tools and APIs to Claude Code. This example shows how to build a simple weather information server using Python and FastMCP.

Use cases for custom MCP servers:
- Internal company APIs
- Custom data sources
- Specialized workflows
- Integration with proprietary tools

---

## What We'll Build

A weather MCP server with three tools:
1. `get_current_weather` - Get current weather for a location
2. `get_forecast` - Get 5-day forecast
3. `get_weather_alerts` - Get active weather alerts

---

## Prerequisites

- Python 3.10 or higher
- `uv` package manager (recommended) or `pip`
- Basic Python knowledge
- OpenWeatherMap API key (free tier: https://openweathermap.org/api)

---

## Step 1: Project Setup

```bash
# Create project directory
mkdir ~/weather-mcp-server
cd ~/weather-mcp-server

# Initialize Python project with uv
uv init

# Or create virtual environment manually
python3 -m venv venv
source venv/bin/activate
```

---

## Step 2: Install Dependencies

```bash
# Using uv (recommended)
uv add fastmcp httpx

# Or using pip
pip install fastmcp httpx
```

---

## Step 3: Create the MCP Server

Create `server.py`:

```python
#!/usr/bin/env python3
"""
Weather MCP Server - Provides weather information tools
"""

import os
from typing import Optional
import httpx
from fastmcp import FastMCP

# Initialize FastMCP server
mcp = FastMCP("Weather Information")

# Get API key from environment
API_KEY = os.getenv("OPENWEATHER_API_KEY")
BASE_URL = "https://api.openweathermap.org/data/2.5"


@mcp.tool()
async def get_current_weather(
    location: str,
    units: str = "metric"
) -> dict:
    """
    Get current weather conditions for a location.

    Args:
        location: City name (e.g., "London", "New York, US")
        units: Temperature units - "metric" (Celsius) or "imperial" (Fahrenheit)

    Returns:
        Current weather data including temperature, conditions, humidity, wind
    """
    if not API_KEY:
        return {"error": "OPENWEATHER_API_KEY not set"}

    async with httpx.AsyncClient() as client:
        response = await client.get(
            f"{BASE_URL}/weather",
            params={
                "q": location,
                "appid": API_KEY,
                "units": units
            }
        )

        if response.status_code != 200:
            return {"error": f"API error: {response.status_code}"}

        data = response.json()

        return {
            "location": data["name"],
            "country": data["sys"]["country"],
            "temperature": data["main"]["temp"],
            "feels_like": data["main"]["feels_like"],
            "conditions": data["weather"][0]["description"],
            "humidity": data["main"]["humidity"],
            "wind_speed": data["wind"]["speed"],
            "units": units
        }


@mcp.tool()
async def get_forecast(
    location: str,
    units: str = "metric"
) -> dict:
    """
    Get 5-day weather forecast for a location.

    Args:
        location: City name (e.g., "London", "New York, US")
        units: Temperature units - "metric" (Celsius) or "imperial" (Fahrenheit)

    Returns:
        5-day forecast with 3-hour intervals
    """
    if not API_KEY:
        return {"error": "OPENWEATHER_API_KEY not set"}

    async with httpx.AsyncClient() as client:
        response = await client.get(
            f"{BASE_URL}/forecast",
            params={
                "q": location,
                "appid": API_KEY,
                "units": units
            }
        )

        if response.status_code != 200:
            return {"error": f"API error: {response.status_code}"}

        data = response.json()

        # Simplify forecast data
        forecast_list = []
        for item in data["list"][:8]:  # Next 24 hours
            forecast_list.append({
                "datetime": item["dt_txt"],
                "temperature": item["main"]["temp"],
                "conditions": item["weather"][0]["description"],
                "precipitation_probability": item.get("pop", 0) * 100
            })

        return {
            "location": data["city"]["name"],
            "country": data["city"]["country"],
            "forecast": forecast_list,
            "units": units
        }


@mcp.tool()
async def get_weather_alerts(
    latitude: float,
    longitude: float
) -> dict:
    """
    Get active weather alerts for coordinates.

    Args:
        latitude: Latitude coordinate
        longitude: Longitude coordinate

    Returns:
        Active weather alerts and warnings
    """
    if not API_KEY:
        return {"error": "OPENWEATHER_API_KEY not set"}

    async with httpx.AsyncClient() as client:
        response = await client.get(
            "https://api.openweathermap.org/data/3.0/onecall",
            params={
                "lat": latitude,
                "lon": longitude,
                "appid": API_KEY,
                "exclude": "current,minutely,hourly,daily"
            }
        )

        if response.status_code != 200:
            return {"error": f"API error: {response.status_code}"}

        data = response.json()
        alerts = data.get("alerts", [])

        if not alerts:
            return {"message": "No active weather alerts"}

        return {
            "alerts_count": len(alerts),
            "alerts": [
                {
                    "event": alert["event"],
                    "start": alert["start"],
                    "end": alert["end"],
                    "description": alert["description"]
                }
                for alert in alerts
            ]
        }


if __name__ == "__main__":
    # Run the MCP server
    mcp.run()
```

---

## Step 4: Make Server Executable

```bash
chmod +x server.py
```

---

## Step 5: Test Locally

```bash
# Set API key
export OPENWEATHER_API_KEY="your_api_key_here"

# Test the server
python3 server.py
```

You should see FastMCP server starting. Test by sending MCP requests (or continue to integration).

---

## Step 6: Configure Claude Code

Edit `~/.claude.json`:

```json
{
  "mcpServers": {
    "weather": {
      "transport": {
        "type": "stdio",
        "command": "python3",
        "args": [
          "/Users/yourusername/weather-mcp-server/server.py"
        ]
      },
      "env": {
        "OPENWEATHER_API_KEY": "${OPENWEATHER_API_KEY}"
      }
    }
  }
}
```

**Important**: Use absolute path to server.py

---

## Step 7: Set Environment Variable

```bash
# Add to ~/.zshrc or ~/.bashrc
echo 'export OPENWEATHER_API_KEY="your_api_key_here"' >> ~/.zshrc
source ~/.zshrc
```

---

## Step 8: Restart Claude Code and Test

In Claude Code:

```
What's the current weather in London?
```

```
Get me the 5-day forecast for Tokyo
```

```
Are there any weather alerts for latitude 40.7128, longitude -74.0060?
```

---

## How It Works

### FastMCP Decorators

```python
@mcp.tool()
def tool_name(param: type) -> return_type:
    """
    Description shown to Claude.

    Args:
        param: Parameter description

    Returns:
        Return value description
    """
    # Implementation
```

- `@mcp.tool()` registers a Python function as an MCP tool
- Docstrings become tool descriptions for Claude
- Type hints define parameter and return types
- FastMCP handles serialization and MCP protocol

### Transport: stdio

- Claude Code launches server as subprocess
- Communication via stdin/stdout
- Server runs only when needed
- Automatic lifecycle management

### Environment Variables

- Passed from `mcp.json` to server process
- Keeps secrets out of code
- Allows configuration per environment

---

## Customization Ideas

### Add Caching

```python
from functools import lru_cache
from datetime import datetime, timedelta

# Cache for 5 minutes
@lru_cache(maxsize=100)
def _cached_weather(location: str, timestamp: int):
    # Round timestamp to 5-minute intervals
    rounded_time = (timestamp // 300) * 300
    # Actual API call
    ...

@mcp.tool()
async def get_current_weather(location: str):
    timestamp = int(datetime.now().timestamp())
    return _cached_weather(location, timestamp)
```

### Add Error Handling

```python
@mcp.tool()
async def get_current_weather(location: str):
    try:
        # API call
        ...
    except httpx.TimeoutException:
        return {"error": "API request timed out"}
    except httpx.HTTPError as e:
        return {"error": f"HTTP error: {str(e)}"}
    except Exception as e:
        return {"error": f"Unexpected error: {str(e)}"}
```

### Add Logging

```python
import logging

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    filename='/tmp/weather-mcp.log'
)

logger = logging.getLogger(__name__)

@mcp.tool()
async def get_current_weather(location: str):
    logger.info(f"Getting weather for {location}")
    # ... implementation
    logger.info(f"Weather retrieved successfully for {location}")
```

### Add Resources (Read-Only Data)

```python
@mcp.resource("weather://config")
def get_config():
    """Server configuration and supported locations"""
    return {
        "api_version": "2.5",
        "supported_units": ["metric", "imperial"],
        "max_forecast_days": 5
    }
```

---

## Common Issues

### Issue: "OPENWEATHER_API_KEY not set"

**Solution**:
- Verify environment variable: `echo $OPENWEATHER_API_KEY`
- Check `mcp.json` has correct env configuration
- Restart Claude Code after setting variable

### Issue: "Module not found: fastmcp"

**Solution**:
```bash
# Ensure dependencies are installed
uv add fastmcp httpx

# Or with pip
pip install fastmcp httpx

# Use absolute path to Python with packages
which python3
# Update command in mcp.json to use this path
```

### Issue: "Permission denied"

**Solution**:
```bash
chmod +x server.py
# Or use explicit python3 command in mcp.json
```

### Issue: "API rate limit exceeded"

**Solution**:
- Add caching to reduce API calls
- Upgrade OpenWeatherMap plan
- Implement exponential backoff

### Issue: "Server not responding"

**Solution**:
- Check server logs: `/tmp/weather-mcp.log`
- Test server manually: `python3 server.py`
- Verify absolute path in `mcp.json`
- Check Python version: `python3 --version` (need 3.10+)

---

## Best Practices

1. **Use type hints** - Helps FastMCP generate correct schemas
2. **Write clear docstrings** - Claude uses these to understand tools
3. **Handle errors gracefully** - Return error objects, don't crash
4. **Validate inputs** - Check parameters before API calls
5. **Add logging** - Essential for debugging MCP issues
6. **Use environment variables** - Never hardcode secrets
7. **Implement caching** - Reduce API calls and improve speed
8. **Test locally first** - Verify server works before integrating

---

## Next Steps

- Add more weather tools (UV index, air quality, historical data)
- Implement caching with TTL
- Add support for multiple weather APIs (fallback)
- Create comprehensive error handling
- Add unit tests
- Package as proper Python module
- Publish to PyPI for easy installation

---

## Alternative: TypeScript MCP Server

For Node.js/TypeScript, use the MCP SDK:

```typescript
import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";

const server = new Server({
  name: "weather-server",
  version: "1.0.0"
});

server.setRequestHandler("tools/call", async (request) => {
  // Handle tool calls
});

const transport = new StdioServerTransport();
await server.connect(transport);
```

See MCP SDK documentation for complete examples.

---

## Resources

- FastMCP Documentation: https://github.com/jlowin/fastmcp
- MCP Specification: https://spec.modelcontextprotocol.io/
- OpenWeatherMap API: https://openweathermap.org/api
- MCP TypeScript SDK: https://github.com/modelcontextprotocol/typescript-sdk
- Example MCP Servers: https://github.com/modelcontextprotocol/servers
