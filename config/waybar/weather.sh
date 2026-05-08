#!/bin/bash
# Fetch weather for Ain Maabed, Djelfa, Algeria from wttr.in
# Outputs JSON for waybar custom module.
# Cache 10 min to avoid hammering wttr.in and survive brief offline periods.

CACHE="$HOME/.cache/waybar-weather.json"
TTL=600  # seconds
LOC="Djelfa"  # Ain Maabed isn't always recognized; Djelfa is the wilaya capital ~50km away

mkdir -p "$(dirname "$CACHE")"

fresh=0
if [ -f "$CACHE" ]; then
    age=$(( $(date +%s) - $(stat -c %Y "$CACHE" 2>/dev/null || echo 0) ))
    [ "$age" -lt "$TTL" ] && fresh=1
fi

if [ "$fresh" -eq 0 ]; then
    # Format: temperature_C|condition_code|feels_like_C|humidity|wind_kmh
    raw=$(curl -fsS --max-time 5 "https://wttr.in/${LOC}?format=%t|%C|%f|%h|%w" 2>/dev/null)
    if [ -n "$raw" ]; then
        IFS='|' read -r temp cond feels hum wind <<< "$raw"
        # Strip leading + sign on temps
        temp="${temp#+}"
        feels="${feels#+}"

        case "$cond" in
            *Sunny*|*Clear*)              icon="☀️" ;;
            *"Partly cloudy"*)            icon="⛅" ;;
            *Cloudy*|*Overcast*)          icon="☁️" ;;
            *Rain*|*Drizzle*|*Shower*)    icon="🌧️" ;;
            *Thunder*)                    icon="⛈️" ;;
            *Snow*|*Sleet*|*Blizzard*)    icon="❄️" ;;
            *Fog*|*Mist*|*Haze*)          icon="🌫️" ;;
            *)                            icon="🌡️" ;;
        esac

        # Escape quotes in tooltip
        cond_esc="${cond//\"/\\\"}"
        printf '{"text":"%s %s","tooltip":"%s in %s\\nFeels like: %s\\nHumidity: %s\\nWind: %s","class":"weather"}\n' \
            "$icon" "$temp" "$cond_esc" "$LOC" "$feels" "$hum" "$wind" > "$CACHE"
    fi
fi

if [ -f "$CACHE" ]; then
    cat "$CACHE"
else
    printf '{"text":"🌡️ --","tooltip":"Weather unavailable","class":"weather-error"}\n'
fi
