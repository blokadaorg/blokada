#include <stdarg.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>

typedef struct Client Client;

typedef struct {
  char *body;
  char *error;
  uint16_t code;
} Response;

void api_close(Client *c);

Client *api_new(void (*log_printer)(const char*));

Response *api_request(Client *client,
                      const char *method,
                      const char *url,
                      const char *body,
                      void (*log_printer)(const char*));

void api_response_free(Response *response);
