#!/usr/bin/env bash

set_tmux_option() {
  local option="$1"
  local value="$2"
  tmux set-option -gq "$option" "$value"
}

get_tmux_option() {
  local option="$1"
  local default_value="$2"
  local option_value="$(tmux show-option -gqv "$option")"
  if [ -z "$option_value" ]; then
    echo "$default_value"
  else
    echo "$option_value"
  fi
}

get_primary_ip_macos() {
  local vpn_active="false"
  local vpn_ip=""
  local vpn_if=""
  local local_ip=""
  local local_if=""
  local icon="unknown"

  # Step 1: Get default interface from route
  default_if=$(route -n get 8.8.8.8 2> /dev/null | awk '/interface: / { print $2 }')

  if echo "$default_if" | grep -qE '^utun|^tun|^ipsec'; then
    vpn_active="true"
    vpn_if="$default_if"
    vpn_ip=$(ipconfig getifaddr "$vpn_if" 2>/dev/null)
  fi

  # Step 2: Try to get local IP from en interfaces
  for iface in en0 en1; do
    local_ip=$(ipconfig getifaddr "$iface" 2>/dev/null)
    if [ -n "$local_ip" ]; then
      local_if="$iface"
      break
    fi
  done

  # Step 3: Decide what to display
  if [ "$vpn_active" = "true" ]; then
    icon="vpn"
    if [ -n "$vpn_ip" ]; then
      printf "%s:%s" "$icon" "$vpn_ip"
    elif [ -n "$local_ip" ]; then
      printf "%s:%s" "$icon" "$local_ip"
    else
      printf "%s:%s" "$icon" "no ip"
    fi
  elif [ -n "$local_ip" ]; then
    if ifconfig "$local_if" 2>/dev/null | grep -q "media.*baseT"; then
      icon="ethernet"
    else
      icon="wifi"
    fi
    printf "%s:%s" "$icon" "$local_ip"
  else
    printf "%s:%s" "unknown" "no ip"
  fi
}

get_primary_ip_freebsd () {
    if="NONE"
    route_str="$(route -n get 8.8.8.8 2> /dev/null | grep 'interface:' | awk '{ print $2 }')"
    if [ -n "${route_str}" ]; then
        if="${route_str}"
        ip="$(ifconfig ${if} 2> /dev/null | grep 'inet ' | awk -F ' ' '{ print $2 }')"
    else
      ip="no internet"
    fi

    case "${if}" in
      vt*)
        ethernet="$(ifconfig ${if} | grep 'media:' | grep 'base-T')"
        if [ -n "${ethernet}" ]; then
          icon="ethernet"
        else
          icon="wifi"
        fi
        ;;
      tun*|utun*|ipsec*|wg*|tailscale*)
        icon="vpn"
        ;;
      *)
        icon="unkown"
        ;;
    esac

    printf "%s:%s" "${icon}" "${ip}"
}

get_primary_ip_linux() {
  if="NONE"
  route_str="$(ip route get 8.8.8.8 2> /dev/null | head -1)"
  if [ -n "${route_str}" ]; then
    ip=$(echo "${route_str}" | cut -d' ' -f7)
    default_if=$(echo "${route_str}" | awk '{for (i=1; i<NF; i++) if ($i == "dev") {print $(i+1); break}}')
    if=$(nmcli con show --active | grep -h "${default_if}" | awk '{print $(NF-1)}' | head -n 1)
  else
    ip="no internet"
  fi

  case "${if}" in
    ethernet)
      icon="ethernet"
      ;;
    wifi)
      icon="wifi"
      ;;
    vpn|wireguard)
      icon="vpn"
      ;;
    *)
      icon="unknown"
      ;;
  esac

  printf "%s:%s" "${icon}" "${ip}"
}

get_primary_ip() {
  case "$(uname -s)" in
    Darwin*)
      get_primary_ip_macos
      ;;
    FreeBSD*)
      get_primary_ip_freebsd
      ;;
    *)
      get_primary_ip_linux
      ;;
  esac
}
