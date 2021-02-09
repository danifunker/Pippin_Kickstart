AS      = m68k-apple-macos-as
ASFLAGS = -l
LD      = m68k-apple-macos-ld
LDFLAGS = --oformat binary
RM      = rm

BIN     = PippinKickstart.bin
SRCS    = PippinKickstart.s
OBJS    = ${SRCS:.s=.o}

.SUFFIXES: .s .o

.s.o:
	$(AS) $(ASFLAGS) $< -o $@

all: $(BIN)

$(BIN): $(OBJS)
	$(LD) $(LDFLAGS) -o $@ $(OBJS)

clean:
	-$(RM) -f $(BIN) $(OBJS)

.PHONY: clean
