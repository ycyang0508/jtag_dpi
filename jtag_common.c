#include <stdio.h>
#include <string.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <stdlib.h>
#include <sys/socket.h>
#include <sys/types.h>


#include "jtag_common.h"

#define RSP_SERVER_PORT	5555

int listenfd = 0;
int connfd = 0;

int init_jtag_server(int port)
{
	struct sockaddr_in serv_addr;
	int flags;
    int yes = 1;

	printf("Listening on port %d\n", port);

    memset(&serv_addr, '0', sizeof(serv_addr));
	serv_addr.sin_family = AF_INET;
	serv_addr.sin_addr.s_addr = htonl(INADDR_ANY);
	serv_addr.sin_port = htons(port);


    listenfd = socket(AF_INET, SOCK_STREAM, 0);

    
    if(setsockopt(listenfd, SOL_SOCKET, SO_REUSEADDR, &yes, sizeof(int)) == -1) {
        fprintf(stderr, "Unable to setsockopt on the socket: %s\n", strerror(errno));
        return;
    }


	bind(listenfd, (struct sockaddr*)&serv_addr, sizeof(serv_addr));

	listen(listenfd, -1);

	printf("Waiting for client connection...");
	connfd = accept(listenfd, (struct sockaddr*)NULL, NULL);
	printf("ok listenfd %d\n",listenfd);

	flags = fcntl(listenfd, F_GETFL, 0);
	fcntl(listenfd, F_SETFL, flags | O_NONBLOCK);


    flags = fcntl(connfd, F_GETFL, 0);
	fcntl(connfd, F_SETFL, flags | O_NONBLOCK);

	return 0;
}

// See if there's anything on the FIFO for us

int check_for_command(struct jtag_cmd *vpi) {
	int nb;
    int flag;
	// Get the command from TCP server
	if(!connfd)
    {
	  init_jtag_server(RSP_SERVER_PORT);
    }

    printf("before recv %d\n",listenfd);
    flag = 0;
    //nb = read(connfd, vpi, sizeof(struct jtag_cmd));
    nb = recv(connfd,vpi,sizeof(struct jtag_cmd),flag);
    printf("after recv %d legnth %d errorno %d\n",listenfd,nb,errno);

	if (((nb < 0) && (errno == EAGAIN)) || (nb == 0)) {
		// Nothing in the fifo this time, let's return        
        perror("check_for_command_0 err\n");
        return 1;
	} else {
		if (nb < 0) {
			// some sort of error
            printf("check_for_command_1 err\n");
            return 1;
			//exit(1);
		}
	}

    //printf("after recv %d\n",listenfd);
	return 0;
}

int send_result_to_server(struct jtag_cmd *vpi) {
	ssize_t n;
    int flag;
	

    printf("before send %d %d\n",listenfd,vpi->length);

    flag = 0;
    n = send(connfd,vpi,sizeof(struct jtag_cmd),flag);
    //n = write(connfd, vpi, sizeof(struct jtag_cmd));
	if (n < (ssize_t)sizeof(struct jtag_cmd))
	  return -1;

    printf("after send %d %d\n",listenfd,n);
	return 0;
}

void jtag_finish(void) {
  	if(connfd)
		printf("Closing RSP server\n");
	close(connfd);
	close(listenfd);
}
