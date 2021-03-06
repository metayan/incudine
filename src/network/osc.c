/*
 * Copyright (c) 2015-2016 Tito Latini
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
 *
 */

#include "osc.h"

int osc_address_new(struct osc_address **addr, const char *host,
                    unsigned int port, int is_datagram, int is_input,
                    int hints_flags)
{
        struct addrinfo hints, *info;
        struct osc_address *a;
        char service[6];
        int ret;

        memset(&hints, 0, sizeof hints);
        hints.ai_family = AF_UNSPEC;
        hints.ai_socktype = is_datagram ? SOCK_DGRAM : SOCK_STREAM;
        hints.ai_flags = hints_flags;

        snprintf(service, 6, "%d", port);
        if ((ret = getaddrinfo(host, service, &hints, &info)) != 0)
                return ret;

        a = (struct osc_address *) malloc(sizeof(struct osc_address));
        if (a == NULL) {
                freeaddrinfo(info);
                return -1;
        }
        if (is_input) {
                a->saddr = (struct sockaddr_storage *)
                        malloc(sizeof(struct sockaddr_storage));
                if (a->saddr == NULL) {
                        freeaddrinfo(info);
                        free(a);
                        return -1;
                }
                a->saddr_len = sizeof(struct sockaddr_storage);
        } else {
                a->saddr = (struct sockaddr_storage *) info->ai_addr;
                a->saddr_len = info->ai_addrlen;
        }
        a->info = info;
        *addr = a;
        return 0;
}

void osc_address_free(struct osc_address *a)
{
        if (a != NULL) {
                if (a->saddr != NULL) {
                        if (a->saddr != (struct sockaddr_storage *)
                                                a->info->ai_addr)
                                free(a->saddr);
                        a->saddr = NULL;
                }
                if (a->info != NULL) {
                        freeaddrinfo(a->info);
                        a->info = NULL;
                }
                free(a);
        }
}

/*
 * Return 1 if the OSC address pattern and the OSC type tag strings match.
 * Return 0 otherwise.
 */
int check_osc_pattern(void *buf, const char *address, const char *types)
{
        char *s1, *s2;
        int i;

        s1 = (char *) buf;
        s2 = (char *) address;

        for (i = 0; *s1 != 0 && *s2 != 0; i++)
                if (*s1++ != *s2++)
                        return 0;

        if ((*s1 != *s2)
            || (strcmp(types, (char *) (buf + osc_fix_size(i) + 1)) != 0))
                return 0;

        return 1;
}

/*
 * Fill the array of pointers ibuf with the pointers to the memory
 * used to store the data of the received OSC message.
 */
int index_osc_values(void *oscbuf, void *ibuf, char *typebuf,
                     unsigned int types_start, unsigned int data_start)
{
        char *ttag, **res, **values, *tbuf;
        uint32_t *data;
        int i = 0;

        res = (char **) ibuf;
        ttag = *res = ((char *) oscbuf) + types_start;
        data = (uint32_t *) (((char *) oscbuf) + data_start);
        /* The second slot is reserved for the pointer to the free memory. */
        values = res + DATA_INDEX_OFFSET;
        res = values;
        /* The first slot is reserved for the number of the required values. */
        tbuf = typebuf + 1;

        while (*ttag) {
                *res = (char *) &data[i];
                *tbuf = *ttag;
                switch (*ttag++) {
                case 'f':    /* float */
                case 'i':    /* int32 */
                case 'c':    /* char */
                        i++;
                        tbuf++;
                        break;
                case 'd':    /* double float */
                case 'h':    /* int64 */
                        i += 2;
                        tbuf++;
                        break;
                case 's':    /* string */
                case 'S':    /* symbol */
                        i += strlen((char *) &data[i]) / 4 + 1;
                        tbuf++;
                        break;
                case 'b':    /* blob */
                        i += data[i] / 4 + 2;
                        tbuf++;
                        break;
                case 't':    /* timetag */
                        i += 2;
                        tbuf++;
                        break;
                case 'm':    /* midi */
                        i++;
                        tbuf++;
                        break;
                default:
                        /*
                         * Other required types in OSC 1.1:
                         *
                         *     T - TRUE
                         *     F - FALSE
                         *     N - NIL
                         *     I - INFINITUM
                         */
                        continue;
                }
                res++;
        }
        /* Start of free memory. */
        *res = (char *) &data[i];
        /* Number of the required values. */
        typebuf[REQUIRED_VALUES_INDEX] = (char**) res - (char **) values;
        res = (char **) ibuf;
        res[MEM_FREE_INDEX] = (char *) &data[i];

        return i;
}

#ifdef LITTLE_ENDIAN
/*
 * Similar to `index_osc_values', but the order of the bytes are swapped
 * on little endian machines.
 */
int index_osc_values_le(void *oscbuf, void *ibuf, char *typebuf,
                        unsigned int types_start, unsigned int data_start)
{
        char *ttag, **res, **values, *tbuf;
        uint32_t *data, tmp;
        int i = 0;

        res = (char **) ibuf;
        ttag = *res = ((char *) oscbuf) + types_start;
        data = (uint32_t *) (((char *) oscbuf) + data_start);
        /* The second slot is reserved for the pointer to the free memory. */
        values = res + DATA_INDEX_OFFSET;
        res = values;
        /* The first slot is reserved for the number of the required values. */
        tbuf = typebuf + 1;

        while (*ttag) {
                *res = (char *) &data[i];
                *tbuf = *ttag;
                switch (*ttag++) {
                case 'f':    /* float */
                case 'i':    /* int32 */
                case 'c':    /* char */
                        data[i] = htonl(data[i]);
                        i++;
                        tbuf++;
                        break;
                case 'd':    /* double float */
                case 'h':    /* int64 */
                        tmp = (uint32_t) data[i];
                        data[i] = htonl(data[i+1]);
                        data[i+1] = htonl(tmp);
                        i += 2;
                        tbuf++;
                        break;
                case 's':    /* string */
                case 'S':    /* symbol */
                        i += strlen((char *) &data[i]) / 4 + 1;
                        tbuf++;
                        break;
                case 'b':    /* blob */
                        data[i] = htonl(data[i]);
                        i += data[i] / 4 + 2;
                        tbuf++;
                        break;
                case 't':    /* timetag */
                        /*
                         * No time tag semantics in OSC 1.1. However, the least
                         * significant bit is reserved to mean "immediately".
                         */
                        i += 2;
                        tbuf++;
                        break;
                case 'm':    /* midi */
                        i++;
                        tbuf++;
                        break;
                default:
                        /*
                         * Other required types in OSC 1.1:
                         *
                         *     T - TRUE
                         *     F - FALSE
                         *     N - NIL
                         *     I - INFINITUM
                         */
                        continue;
                }
                res++;
        }
        /* Start of free memory. */
        *res = (char *) &data[i];
        /* Number of the required values. */
        typebuf[REQUIRED_VALUES_INDEX] = (char**) res - (char **) values;
        res = (char **) ibuf;
        res[MEM_FREE_INDEX] = (char *) &data[i];
        *tbuf = 0;
        return i;
}
#endif  /* LITTLE_ENDIAN */

/*
 * Write the OSC address pattern and the OSC type tag, then update the
 * pointers to the memory used for the required values.
 */
unsigned int osc_start_message(void *buf, unsigned int bufsize, void *ibuf,
                               char *tbuf, const char *address,
                               const char *types)
{
        int i, ttag_start;
        char *tmp, **data;

        tmp = (char *) buf;
        memset(buf, 0, bufsize);
        for (i = 0; *address != 0; i++)
                tmp[i] = *address++;
        i = osc_fix_size(i);
        tmp[i++] = ',';
        ttag_start = i;
        for (; *types != 0; i++)
                tmp[i] = *types++;
        index_osc_values(buf, ibuf, tbuf, ttag_start, osc_fix_size(i));
        data = (char **) ibuf;
        return data[MEM_FREE_INDEX] - (char *) buf;
}

/*
 * The space required to store a string or a blob is variable. For example,
 * if the new received blob is bigger than the previous blob and there are
 * other data after the blob, it is necessary to reserve more space by
 * moving to right these data.
 */
int osc_maybe_reserve_space(void *oscbuf, void *ibuf, unsigned int index,
                            unsigned int data_size)
{
        unsigned int old_size;
        uint32_t **data;
        unsigned int res, i;

        data = (uint32_t **) ibuf;
        old_size = (char *) data[index + 1] - (char *) data[index];
        if (old_size > data_size) {
                res = (old_size - data_size) >> 2;
                osc_move_data_left(data[index + 1], data[MEM_FREE_INDEX], res);
                /* Update data pointer index. */
                for (i = index + 1; data[i] < data[MEM_FREE_INDEX]; i++)
                        data[i] -= res;
                /* The last slot is the start of the free memory. */
                data[i] -= res;
                data[MEM_FREE_INDEX] = data[i];
                *(data[index + 1] - 1) = 0;  /* Zero padding. */
        } else if (old_size < data_size) {
                res = (data_size - old_size) >> 2;
                osc_move_data_right(data[index + 1], data[MEM_FREE_INDEX], res);
                for (i = index + 1; data[i] < data[MEM_FREE_INDEX]; i++)
                        data[i] += res;
                data[i] += res;
                data[MEM_FREE_INDEX] = data[i];
                *(data[index + 1] - 1) = 0;
        }
        return (char *) data[MEM_FREE_INDEX] - (char *) oscbuf;
}

static void osc_move_data_left(uint32_t *start, uint32_t *end, unsigned int n)
{
        uint32_t *curr;

        for (curr = start; curr < end; curr++)
                *(curr - n) = *curr;
}

static void osc_move_data_right(uint32_t *start, uint32_t *end, unsigned int n)
{
        uint32_t *curr, *arr_last;

        for (curr = end - 1, arr_last = start - 1; curr > arr_last; curr--)
                *(curr + n) = *curr;
}

struct osc_fds *osc_alloc_fds(void)
{
        struct osc_fds *o;

        o = (struct osc_fds *) malloc(sizeof(struct osc_fds));
        if (o != NULL) {
                FD_ZERO(&o->fds);
                o->servfd = o->lastfd = -1;
                o->maxfd = 0;
                o->count = 0;
        }
        return o;
}

void osc_set_servfd(struct osc_fds *o, int servfd)
{
        FD_SET(servfd, &o->fds);
        o->maxfd = o->servfd = servfd;
}

int osc_lastfd(struct osc_fds *o)
{
        return o->lastfd;
}

int osc_connections(struct osc_fds *o)
{
        return o->count;
}

void osc_close_connections(struct osc_fds *o)
{
        int i;

        for (i = 0; i <= o->maxfd; i++)
                if (FD_ISSET(i, &o->fds) && i != o->servfd)
                        close(i);
        FD_ZERO(&o->fds);
        FD_SET(o->servfd, &o->fds);
        o->maxfd = o->servfd;
        o->lastfd = -1;
        o->count = 0;
}

int osc_next_fd_set(struct osc_fds *o, int curr)
{
        int i;

        if (curr < 3 || curr >= o->maxfd)
                return -1;
        for (i = curr + 1; i <= o->maxfd; i++)
                if (FD_ISSET(i, &o->fds) && i != o->servfd)
                        return i;
        return -1;
}

int osc_close_server(struct osc_fds *o)
{
        return close(o->servfd);
}

/* Receiver used with stream-oriented protocols. */
int osc_recv(struct osc_fds *o, struct osc_address *addr, void *buf,
             unsigned int maxlen, int enc_flags, int flags)
{
        int i, ret, fd, remain, nbytes, nfds, is_slip, has_count_prefix;
        unsigned char *data;
        fd_set fds, tmpfds;
        struct timeval now, *timeout;

        if (osc_getsock_nonblock(o->servfd)) {
                now.tv_sec = now.tv_usec = 0;
                timeout = &now;
        } else {
                timeout = NULL;
        }
        is_slip = enc_flags & SLIP_ENCODING_FLAG;
        has_count_prefix = enc_flags & COUNT_PREFIX_FLAG;
        FD_ZERO(&fds);
        nbytes = 0;
        while(1) {
                fds = o->fds;
                nfds = o->maxfd + 1;
                if ((ret = select(nfds, &fds, NULL, NULL, timeout)) <= 0)
                        return ret;
                if (FD_ISSET(o->servfd, &fds)) {
                        addr->saddr_len = sizeof(struct sockaddr_storage);
                        fd = accept(o->servfd, (struct sockaddr *) addr->saddr,
                                    &addr->saddr_len);
                        if (fd != -1) {
                                FD_SET(fd, &o->fds);
                                o->count++;
                                if (fd > o->maxfd)
                                        o->maxfd = fd;
                        }
                }
                FD_LOOP(i, nfds, fds) {
                        if (i != o->servfd) {
                                data = (unsigned char *) buf;
                                ret = recv(i, data, maxlen, flags);
                                if (ret == 0) {
                                        close(i);
                                        FD_CLR(i, &o->fds);
                                        if (o->lastfd == i)
                                                o->lastfd = -1;
                                        if (--o->count == 0) {
                                                o->maxfd = o->servfd;
                                                break;
                                        } else {
                                                continue;
                                        }
                                }
                                o->lastfd = i;
                                if (is_slip) {
                                        /* Serial Line IP */
                                        if (is_slip_msg(data, ret))
                                                return ret;
                                        nbytes = maxlen;
                                        remain = nbytes - ret;
                                } else if (has_count_prefix) {
                                        /*
                                         * OSC 1.0 spec: length-count prefix on
                                         * the start of the packet.
                                         */
                                        nbytes = htonl(*((uint32_t *) data));
                                        if (nbytes > maxlen - 4) {
                                                nbytes = OSC_MSGTOOLONG;
                                                remain = maxlen - ret;
                                        } else {
                                                remain = nbytes + 4 - ret;
                                        }
                                } else {
                                        return ret;
                                }
                                while (remain > 0) {
                                        FD_ZERO(&tmpfds);
                                        FD_SET(i, &tmpfds);
                                        /* Timeout considered undefined. */
                                        now.tv_sec = now.tv_usec = 0;
                                        if ((select(i + 1, &tmpfds, NULL, NULL,
                                                    &now) != -1)
                                            && FD_ISSET(i, &tmpfds)) {
                                                data += ret;
                                                ret = recv(i, data, remain,
                                                           flags);
                                                if (ret <= 0) {
                                                        close(i);
                                                        if (o->lastfd == i)
                                                                o->lastfd = -1;
                                                        if (--o->count == 0)
                                                                o->maxfd =
                                                                      o->servfd;
                                                        nbytes = OSC_BADMSG;
                                                        break;
                                                }
                                                remain -= ret;
                                                if (is_slip) {
                                                        if (is_slip_msg(data,
                                                                        ret))
                                                                return nbytes
                                                                       - remain;
                                                        else if (remain == 0)
                                                                nbytes =
                                                                 OSC_MSGTOOLONG;
                                                }
                                        } else {
                                                nbytes = OSC_BADMSG;
                                                break;
                                        }
                                }
                                if (nbytes > 0)
                                        return nbytes;
                        }
                }
                if (nbytes < 0)
                        return nbytes;
                if (timeout == &now) {
                        /* Timeout considered undefined after select() returns. */
                        now.tv_sec = now.tv_usec = 0;
                }
        }
}

/*
 * SLIP (RFC 1055)
 * Transmission of IP datagrams over serial lines.
 */
unsigned int osc_slip_encode(const unsigned char *src, unsigned char *dest,
                             unsigned int len)
{
        unsigned int i, j;

        /* Double END character encoding. */
        dest[0] = SLIP_END;
        for (i = 0, j = 1; i < len; i++, j++) {
                switch (src[i]) {
                case SLIP_END:
                        dest[j++] = SLIP_ESC;
                        dest[j] = SLIP_ESC_END;
                        break;
                case SLIP_ESC:
                        dest[j++] = SLIP_ESC;
                        dest[j] = SLIP_ESC_ESC;
                        break;
                default:
                        dest[j] = src[i];
                }
        }
        dest[j++] = SLIP_END;
        dest[j] = 0;
        return j;
}

unsigned int osc_slip_decode(unsigned char *buf, unsigned int maxlen)
{
        unsigned char *dest;
        unsigned int i, j;

        dest = buf;
        for (i = 0, j = 0; i < maxlen; i++) {
                switch (buf[i]) {
                case SLIP_END:
                        if (i) return j;
                        /* Skip initial END characters. */
                        break;
                case SLIP_ESC:
                        if (buf[++i] == SLIP_ESC_END)
                                dest[j++] = SLIP_END;
                        else if (buf[i] == SLIP_ESC_ESC)
                                dest[j++] = SLIP_ESC;
                        break;
                default:
                        dest[j++] = buf[i];
                }
        }
        return j;
}

static int is_slip_msg(const unsigned char *buf, int len)
{
        int i = len - 1;

        while (i > 0)
                if (buf[i--] == SLIP_END)
                        return 1;
        return 0;
}

int osc_getsock_broadcast(int sockfd)
{
        int ret, val;
        socklen_t optlen;

        optlen = sizeof(int);
        ret = getsockopt(sockfd, SOL_SOCKET, SO_BROADCAST, &val, &optlen);
        return ret == 0 ? val : ret;
}

int osc_setsock_broadcast(int sockfd, const struct addrinfo *info, int is_set)
{
        if (info->ai_socktype == SOCK_DGRAM && info->ai_family == AF_INET)
                return setsockopt(sockfd, SOL_SOCKET, SO_BROADCAST, &is_set,
                                  sizeof(int));
        return 0;
}

int osc_getsock_nonblock(int sockfd)
{
        int flags;

        if ((flags = fcntl(sockfd, F_GETFL, 0)) < 0)
                return 0;
        return flags & O_NONBLOCK;
}

int osc_setsock_nonblock(int sockfd, int is_nonblock)
{
        int flags;

        if ((flags = fcntl(sockfd, F_GETFL, 0)) < 0)
                return -1;
        flags = is_nonblock ? flags | O_NONBLOCK : flags & ~O_NONBLOCK;
        return fcntl(sockfd, F_SETFL, flags);
}

int osc_setsock_reuseaddr(int sockfd)
{
        int yes = 1;
        return setsockopt(sockfd, SOL_SOCKET, SO_REUSEADDR, &yes, sizeof(int));
}

unsigned int sizeof_socklen(void)
{
        return sizeof(socklen_t);
}
