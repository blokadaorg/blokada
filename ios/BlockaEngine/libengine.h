#include <stdarg.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>

typedef enum {
  Whitelisted,
  Blocked,
  Passed,
} DNSHistoryAction;

/**
 * Indicates the operation required from the caller
 */
typedef enum {
  /**
   * No operation is required.
   */
  WIREGUARD_DONE = 0,
  /**
   * Write dst buffer to network. Size indicates the number of bytes to write.
   */
  WRITE_TO_NETWORK = 1,
  /**
   * Some error occurred, no operation is required. Size indicates error code.
   */
  WIREGUARD_ERROR = 2,
  /**
   * Write dst buffer to the interface as an ipv4 packet. Size indicates the number of bytes to write.
   */
  WRITE_TO_TUNNEL_IPV4 = 4,
  /**
   * Write dst buffer to the interface as an ipv6 packet. Size indicates the number of bytes to write.
   */
  WRITE_TO_TUNNEL_IPV6 = 6,
} result_type;

typedef struct Client Client;

typedef struct Handle Handle;

/**
 * Tunnel represents a point-to-point WireGuard connection
 */
typedef struct Tunn Tunn;

typedef struct {
  char *body;
  char *error;
  uint16_t code;
} Response;

typedef struct {
  char *name;
  DNSHistoryAction action;
  uint64_t unix_time;
  uint64_t requests;
} DNSHistoryEntry;

typedef struct {
  DNSHistoryEntry *ptr;
  uintptr_t len;
  uint64_t allowed_requests;
  uint64_t denied_requests;
} DNSHistory;

typedef struct {
  const char *public_key;
  const char *private_key;
} x25519_base64_keypair;

/**
 * The return type of WireGuard functions
 */
typedef struct {
  /**
   * The operation to be performed by the caller
   */
  result_type op;
  /**
   * Additional information, required to perform the operation
   */
  uintptr_t size;
} wireguard_result;

typedef struct {
  uint8_t key[32];
} x25519_key;

/**
 * A public X25519, derived from a secret key
 */
typedef struct {
  uint8_t internal[32];
} X25519PublicKey;

/**
 * A secret X25519 key
 */
typedef struct {
  uint8_t internal[32];
} X25519SecretKey;

void api_free(Client *c);

uintptr_t api_hostlist(Client *client, const char *url, const char *path);

Client *api_new(unsigned long long timeout_seconds, const char *user_agent);

Response *api_request(Client *client, const char *method, const char *url, const char *body);

void api_response_free(Response *response);

/**
 * Check if the input C-string represents a valid base64 encoded x25519 key.
 * Return 1 if valid 0 otherwise.
 */
int32_t check_base64_encoded_x25519_key(const char *key);

void dns_close(Handle *h);

DNSHistory dns_history(const Handle *h);

void dns_history_free(DNSHistory history);

bool dns_use_lists(Handle *h, const char *blocklist_filename, const char *whitelist_filename);

void engine_logger(const char *level);

/**
 * Frees memory of the string given by `x25519_base64_keypair`
 */
void keypair_free(x25519_base64_keypair *keypair);

/**
 * Generates a new x25519 secret key.
 */
x25519_base64_keypair *keypair_new(void);

Handle *new_dns(const char *listen_addr,
                const char *blocklist_filename,
                const char *whitelist_filename,
                const char *dns_ips,
                const char *dns_name,
                const char *dns_path);

/**
 * Allocate a new tunnel, return NULL on failure.
 * Keys must be valid base64 encoded 32-byte keys.
 */
Tunn *new_tunnel(const char *static_private,
                 const char *server_static_public,
                 void (*log_printer)(const char*),
                 uint32_t log_level);

void panic_hook(void (*log_printer)(const char*));

/**
 * Drops the Tunn object
 */
void tunnel_free(Tunn *tunnel);

/**
 * Force the tunnel to initiate a new handshake, dst buffer must be at least 148 byte long.
 */
wireguard_result wireguard_force_handshake(Tunn *tunnel, uint8_t *dst, uint32_t dst_size);

/**
 * Read a UDP packet from the server.
 * For more details check noise::network_to_tunnel functions.
 */
wireguard_result wireguard_read(Tunn *tunnel,
                                const uint8_t *src,
                                uint32_t src_size,
                                uint8_t *dst,
                                uint32_t dst_size);

/**
 * This is a state keeping function, that need to be called periodically.
 * Recommended interval: 100ms.
 */
wireguard_result wireguard_tick(Tunn *tunnel, uint8_t *dst, uint32_t dst_size);

/**
 * Write an IP packet from the tunnel interface.
 * For more details check noise::tunnel_to_network functions.
 */
wireguard_result wireguard_write(Tunn *tunnel,
                                 const uint8_t *src,
                                 uint32_t src_size,
                                 uint8_t *dst,
                                 uint32_t dst_size);

/**
 * Returns the base64 encoding of a key as a UTF8 C-string.
 *
 * The memory has to be freed by calling `x25519_key_to_str_free`
 */
const char *x25519_key_to_base64(x25519_key key);

/**
 * Returns the hex encoding of a key as a UTF8 C-string.
 *
 * The memory has to be freed by calling `x25519_key_to_str_free`
 */
const char *x25519_key_to_hex(x25519_key key);

/**
 * Frees memory of the string given by `x25519_key_to_hex` or `x25519_key_to_base64`
 */
void x25519_key_to_str_free(char *stringified_key);

/**
 * Computes a public x25519 key from a secret key.
 */
X25519PublicKey x25519_public_key(X25519SecretKey private_key);

/**
 * Generates a new x25519 secret key.
 */
X25519SecretKey x25519_secret_key(void);
