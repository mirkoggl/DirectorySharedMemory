library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.logpack.all;

entity directory_manager is
	Generic(
		DIRECTORY_ID   : natural := 0;  -- This Directory identifier
		DIRECTORIES_N  : natural := 4;  -- Directories number
		DATA_WIDTH     : natural := 8;  -- Data width
		BLOCK_WIDTH    : natural := 8;  -- Memory address width
		-- Message to/from core width -> memory address width + 1 bit for discern if it is a load or a store request 
		--ROUTER_MEX_WIDTH : natural := 12;

		FIFO_REQ_WIDTH : natural := 8   -- Internal FIFO length. If the controller is busy, concurrent request are stored in the Request FIFO
	);
	Port(
		clk            : in  std_logic;
		reset          : in  std_logic;
		enable         : in  std_logic;

		-- Cache Controller Interface
		CCValidIn      : in  std_logic; -- Core valid signal, high if there is a valid request from the core
		CCGetPutIn     : in  Std_logic; -- Cache Controller operation (put or get)
		CCAddrIn       : in  std_logic_vector(BLOCK_WIDTH - 1 downto 0); -- Request from the core (load and store) 
		CCDataIn       : in  std_logic_vector(DATA_WIDTH - 1 downto 0); -- Data from the core (in case of store)
		CCValidOut     : out std_logic; -- Core valid out, if high there is a valid response for the core 
		CCAckOut       : out std_logic;
		CCAddrOut      : out std_logic_vector(BLOCK_WIDTH - 1 downto 0); -- Response for the core
		CCDataOut      : out std_logic_vector(DATA_WIDTH - 1 downto 0); -- Data from the core (in case of load)

		-- Router Interface
		RouterValidIn  : in  std_logic;
		RouterDataIn   : in  std_logic_vector(f_log2(DIRECTORIES_N) + BLOCK_WIDTH + DATA_WIDTH + 2 - 1 downto 0); -- 2 are the possible message type (Fwd-Get-M and Fwd-Get-S)
		RouterValidOut : out std_logic;
		RouterDataOut  : out std_logic_vector(f_log2(DIRECTORIES_N) + BLOCK_WIDTH + DATA_WIDTH + 2 - 1 downto 0);

		-- Memory interface
		MemDataIn      : in  std_logic_vector(DATA_WIDTH - 1 downto 0);
		MemReadAddr    : out std_logic_vector(BLOCK_WIDTH - f_log2(DIRECTORIES_N) - 1 downto 0);
		MemWriteEn     : out std_logic;
		MemWriteAddr   : out std_logic_vector(BLOCK_WIDTH - f_log2(DIRECTORIES_N) - 1 downto 0);
		MemDataOut     : out std_logic_vector(DATA_WIDTH - 1 downto 0)
	);
end entity directory_manager;

architecture RTL of directory_manager is
	constant STATE_BIT_WIDTH   : natural := 2;
	constant OWNER_WIDTH       : natural := f_log2(DIRECTORIES_N);
	constant SHARER_LIST_WIDTH : natural := DIRECTORIES_N;
	constant DIRECTORY_WIDTH   : natural := STATE_BIT_WIDTH + OWNER_WIDTH + SHARER_LIST_WIDTH;
	constant ADDR_WIDTH        : natural := BLOCK_WIDTH - f_log2(DIRECTORIES_N);

	-- Directory/Controller message constants
	constant GET_BLOCK : std_logic := '0';
	constant PUT_BLOCK : std_logic := '1';

	-- Router/Controller message constants
	constant FWD_GET_M : std_logic_vector(1 downto 0) := "00";
	constant FWD_GET_S : std_logic_vector(1 downto 0) := "01";
	constant FWD_PUT_M : std_logic_vector(1 downto 0) := "10";
	constant PUT_M_ACK : std_logic_vector(1 downto 0) := "11";

	-- MESI State value constant 
	constant INVALID_STATE   : std_logic_vector(STATE_BIT_WIDTH - 1 downto 0) := "00";
	constant MODIFIED_STATE  : std_logic_vector(STATE_BIT_WIDTH - 1 downto 0) := "01";
	constant SHARED_STATE    : std_logic_vector(STATE_BIT_WIDTH - 1 downto 0) := "10";
	constant EXCLUSIVE_STATE : std_logic_vector(STATE_BIT_WIDTH - 1 downto 0) := "11";

	constant NO_DATA : std_logic_vector(DATA_WIDTH - 1 downto 0) := (others => '0');

	--States: 
	--       00 -> Invalid
	--       01 -> Shared
	--       10 -> Modified
	--       11 -> Exclusice
	type directory_entry is record
		state  : std_logic_vector(STATE_BIT_WIDTH - 1 downto 0);
		owner  : std_logic_vector(OWNER_WIDTH - 1 downto 0);
		sharer : std_logic_vector(SHARER_LIST_WIDTH - 1 downto 0);
	end record;

	type directory_t is array ((2 ** ADDR_WIDTH) - 1 downto 0) of directory_entry;

	constant DIRECTORY_ENTRY_INIT : directory_entry := (
		state  => (others => '0'),
		owner  => (others => '0'),
		sharer => (others => '0')
	);
	signal directory : directory_t := (others => DIRECTORY_ENTRY_INIT); -- All directory entry start in Invalid state.

	constant ZERO_SHARER : std_logic_vector(SHARER_LIST_WIDTH - 1 downto 0) := (others => '0');

	--TODO: Core request FIFO. If a request arrives when another is under processing, the request is stored and processed when the first is completed
	--type request_fifo_t is array (FIFO_REQ_WIDTH - 1 downto 0) of std_logic_vector(BLOCK_WIDTH downto 0);
	--signal request_fifo          : request_fifo_t                                        := (others => (others => '0'));
	--signal head_pt, tail_pt      : std_logic_vector(f_log2(FIFO_REQ_WIDTH) - 1 downto 0) := (others => '0');
	--signal fifo_full, fifo_empty : std_logic                                             := '0';

	-- FSM and temporany signals 
	type state_type is (idle, others_req, load_mem, getS, getM, putM, Fwd_GetS, Fwd_PutM, Fwd_GetM, wait_remote_getS, wait_Fwd_PutM, wait_remote_getM, memory_delay, set_sharer);
	signal current_s, next_s : state_type := idle;

	-- Router interface temporany signals
	signal router_data_temp : std_logic_vector(f_log2(DIRECTORIES_N) + BLOCK_WIDTH + DATA_WIDTH + 2 - 1 downto 0) := (others => '0');
	signal router_valid_out : std_logic                                                                           := '0';
	signal router_data_out  : std_logic_vector(f_log2(DIRECTORIES_N) + BLOCK_WIDTH + DATA_WIDTH + 2 - 1 downto 0) := (others => '0');
	signal home_node        : std_logic_vector(f_log2(DIRECTORIES_N) - 1 downto 0)                                := (others => '0');

	signal requestor_id : natural := 0;

	-- Memory interface temporany signals
	signal mem_read_addr_temp  : std_logic_vector(BLOCK_WIDTH - 1 downto 0) := (others => '0');
	signal mem_write_addr_temp : std_logic_vector(BLOCK_WIDTH - 1 downto 0) := (others => '0');
	signal mem_we_temp         : std_logic                                  := '0';
	signal mem_data_out_temp   : std_logic_vector(DATA_WIDTH - 1 downto 0)  := (others => '0');

	-- Cache Controller interfacce temporany signals
	signal cc_valid_out_temp : std_logic                                  := '0'; -- Core valid out, if high there is a valid response for the core 
	signal cc_ack_out_temp   : std_logic                                  := '0';
	signal cc_addr_out_temp  : std_logic_vector(BLOCK_WIDTH - 1 downto 0) := (others => '0'); -- Response for the core
	signal cc_data_out_temp  : std_logic_vector(DATA_WIDTH - 1 downto 0)  := (others => '0'); -- Data from the core (in case of load)

begin
	RouterValidOut <= router_valid_out;
	RouterDataOut  <= router_data_out;

	MemReadAddr  <= mem_read_addr_temp(ADDR_WIDTH - 1 downto 0);
	MemWriteEn   <= mem_we_temp;
	MemDataOut   <= mem_data_out_temp;
	MemWriteAddr <= mem_write_addr_temp(ADDR_WIDTH - 1 downto 0);

	CCValidOut <= cc_valid_out_temp;
	CCAckOut   <= cc_ack_out_temp;
	CCDataOut  <= cc_data_out_temp;
	CCAddrOut  <= cc_addr_out_temp;

	CU_process : process(clk, reset, enable)
	begin
		if reset = '1' then
			next_s    <= idle;
			current_s <= idle;
			directory <= (others => DIRECTORY_ENTRY_INIT);

		elsif rising_edge(clk) and enable = '1' then
			router_valid_out  <= '0';
			cc_valid_out_temp <= '0';
			cc_ack_out_temp   <= '0';
			mem_we_temp       <= '0';

			case current_s is
				when idle =>
					if CCValidIn = '1' then -- A request from Cache Controller
						mem_data_out_temp <= CCDataIn;
						if CCGetPutIn = GET_BLOCK then -- LOAD REQUEST, a load request can be satified if the block is in Shared state
							mem_read_addr_temp <= CCAddrIn;
							-- If this condition is true the current node is the home 
							if CCAddrIn(BLOCK_WIDTH - 1 downto BLOCK_WIDTH - f_log2(DIRECTORIES_N)) = CONV_STD_LOGIC_VECTOR(DIRECTORY_ID, f_log2(DIRECTORIES_N)) then
								if directory(CONV_INTEGER(CCAddrIn(ADDR_WIDTH - 1 downto 0))).state = SHARED_STATE then -- If the block is already in Shared state and it can be load
									current_s <= memory_delay; -- Wait 1 clock cycle for memory response
									next_s    <= load_mem;
								else    -- else we need to get the Shared state for this block
									current_s    <= getS;
									requestor_id <= DIRECTORY_ID;
								end if;
							else
								current_s <= Fwd_GetS;
							end if;
						else            -- STORE REQUEST, a store request can be satisfied if the block is in Modified state
							mem_write_addr_temp <= CCAddrIn;
							-- If this condition is true the current node is the home 
							if CCAddrIn(BLOCK_WIDTH - 1 downto BLOCK_WIDTH - f_log2(DIRECTORIES_N)) = CONV_STD_LOGIC_VECTOR(DIRECTORY_ID, f_log2(DIRECTORIES_N)) then
								if directory(CONV_INTEGER(CCAddrIn(ADDR_WIDTH - 1 downto 0))).state = MODIFIED_STATE then -- If is already in Modified state
									if directory(CONV_INTEGER(CCAddrIn(ADDR_WIDTH - 1 downto 0))).owner = CONV_STD_LOGIC_VECTOR(DIRECTORY_ID, f_log2(DIRECTORIES_N)) then -- The current node is the owner
										-- Ack to Cache Controller
										cc_valid_out_temp <= '1';
										cc_ack_out_temp   <= '1';
										-- Write in Memory
										mem_we_temp       <= '1';
										current_s         <= idle;
									else -- Forward to the Owner
										current_s <= Fwd_GetM;
									end if;
								else    -- else we need to get the Modified state for this block
									current_s    <= putM;
									requestor_id <= DIRECTORY_ID;
								end if;
							else
								current_s <= Fwd_PutM; -- If the current node isn't the home 
							end if;
						end if;
					elsif RouterValidIn = '1' then -- A request from the router
						current_s        <= others_req;
						router_data_temp <= RouterDataIn;
					else
						current_s <= idle;
					end if;

				when load_mem =>        -- Ack to Controller and upload the data				
					cc_valid_out_temp <= '1';
					cc_ack_out_temp   <= '1';
					cc_data_out_temp  <= MemDataIn;
					-- cc_addr_out_temp <= pass the loaded address
					current_s         <= idle;

				when others_req =>
					-- A request from an extern node, read the message 
					if router_data_temp(f_log2(DIRECTORIES_N) + BLOCK_WIDTH + DATA_WIDTH + 2 - 1 downto f_log2(DIRECTORIES_N) + BLOCK_WIDTH + DATA_WIDTH) = FWD_PUT_M then
						current_s           <= putM;
						requestor_id        <= CONV_INTEGER(router_data_temp(f_log2(DIRECTORIES_N) + BLOCK_WIDTH + DATA_WIDTH - 1 downto BLOCK_WIDTH + DATA_WIDTH));
						mem_write_addr_temp <= router_data_temp(BLOCK_WIDTH + DATA_WIDTH - 1 downto DATA_WIDTH);
						mem_data_out_temp <= router_data_temp(DATA_WIDTH - 1 downto 0);
					else
						current_s <= idle;
					end if;

				when getM =>
					current_s <= idle;

				when getS =>
					-- We need to find the home node for this block
					if mem_read_addr_temp(BLOCK_WIDTH - 1 downto BLOCK_WIDTH - f_log2(DIRECTORIES_N)) = CONV_STD_LOGIC_VECTOR(DIRECTORY_ID, f_log2(DIRECTORIES_N)) then -- If this condition is true the current node is the home 
						if directory(CONV_INTEGER(mem_read_addr_temp(ADDR_WIDTH - 1 downto 0))).state = MODIFIED_STATE then -- If the block is modified we need to recall it
							-- Fwd-GetS to the owner and wait for the update data
							if directory(CONV_INTEGER(mem_read_addr_temp(ADDR_WIDTH - 1 downto 0))).owner = CONV_STD_LOGIC_VECTOR(DIRECTORY_ID, f_log2(DIRECTORIES_N)) then
								-- The current node is the owner, can directly read the block
								directory(CONV_INTEGER(mem_read_addr_temp(ADDR_WIDTH - 1 downto 0))).state  <= SHARED_STATE;
								directory(CONV_INTEGER(mem_read_addr_temp(ADDR_WIDTH - 1 downto 0))).sharer <= (others => '0');
								current_s                                                                   <= set_sharer;
							else
								-- Forward the request to the block owner
								current_s <= Fwd_GetS;
							end if;
						else            -- If is invalid or shared the directory can reponse with data to the requestor
							directory(CONV_INTEGER(mem_read_addr_temp(ADDR_WIDTH - 1 downto 0))).state                <= SHARED_STATE;
							directory(CONV_INTEGER(mem_read_addr_temp(ADDR_WIDTH - 1 downto 0))).sharer(requestor_id) <= '1';

							-- Jump to wait 1 cylcle state for memory latency
							current_s <= memory_delay;
							next_s    <= load_mem;
						end if;
					else                -- The block is handled by another node
						-- Send mex to the home node
						router_valid_out <= '1';

						-- Create the message body: Dest + Source + Message type + Block Address Request
						--router_data_out  <= core_mex_temp(MEM_ADDR_WIDTH - 1 downto MEM_ADDR_WIDTH - 1 - f_log2(DIRECTORIES_N)) & CONV_STD_LOGIC_VECTOR(DIRECTORY_ID, f_log2(DIRECTORIES_N)) & FWD_GET_S & core_mex_temp(MEM_ADDR_WIDTH - 1 - f_log2(DIRECTORIES_N) - 1 downto 0);
						home_node <= mem_read_addr_temp(BLOCK_WIDTH - 1 downto BLOCK_WIDTH - f_log2(DIRECTORIES_N));
						current_s <= wait_remote_getS;
					end if;

				when Fwd_GetS =>
					-- Send mex to the home node
					router_valid_out <= '1';

					-- Create the message body: Message type + Source + Dest + Block Address Request + Data
					router_data_out <= FWD_GET_S & CONV_STD_LOGIC_VECTOR(DIRECTORY_ID, f_log2(DIRECTORIES_N)) & mem_read_addr_temp & NO_DATA;
					home_node       <= mem_read_addr_temp(BLOCK_WIDTH - 1 downto BLOCK_WIDTH - f_log2(DIRECTORIES_N));
					current_s       <= wait_remote_getS;

				when wait_remote_getS =>
					-- if RouterValidIn = '1' and RouterDataIn(MEM_ADDR_WIDTH + 2 - 1 downto MEM_ADDR_WIDTH + 2 - f_log2(DIRECTORIES_N)) = home_node then
					-- The home node responded. The controller must save the data in cache and set it has shared
					--	current_s <= idle;
					--else
					--	current_s <= wait_remote_getS;
					--end if;
					current_s <= idle;

				when wait_remote_getM =>
					current_s <= idle;

				when putM =>
					-- We need to find the  home node for this block
					if mem_write_addr_temp(BLOCK_WIDTH - 1 downto BLOCK_WIDTH - f_log2(DIRECTORIES_N)) = CONV_STD_LOGIC_VECTOR(DIRECTORY_ID, f_log2(DIRECTORIES_N)) then -- If this condition is true the current node is the home 
						if directory(CONV_INTEGER(mem_write_addr_temp(ADDR_WIDTH - 1 downto 0))).state = INVALID_STATE then -- If block is invalid and current node is the home
							-- Update block state to Modified and save the Owner
							directory(CONV_INTEGER(mem_write_addr_temp(ADDR_WIDTH - 1 downto 0))).state  <= MODIFIED_STATE; -- Set the block as modified
							directory(CONV_INTEGER(mem_write_addr_temp(ADDR_WIDTH - 1 downto 0))).sharer <= (others => '0'); -- Sharer should be already 0
							directory(CONV_INTEGER(mem_write_addr_temp(ADDR_WIDTH - 1 downto 0))).owner  <= CONV_STD_LOGIC_VECTOR(requestor_id, OWNER_WIDTH); -- Save the Owner

							-- Ack to requestor
							if requestor_id = DIRECTORY_ID then -- If requestor is the Cache Controller
								cc_valid_out_temp <= '1';
								cc_ack_out_temp   <= '1';
							else        -- Else send an Ack to the requestor node
								router_valid_out <= '1';
								-- Create the message body: Message type + Source + Dest + Block Address Request + Data
								router_data_out <= PUT_M_ACK & CONV_STD_LOGIC_VECTOR(DIRECTORY_ID, f_log2(DIRECTORIES_N)) & mem_write_addr_temp & NO_DATA;
							end if;
							-- Write in Memory
							mem_we_temp <= '1';
							current_s   <= idle;
						elsif directory(CONV_INTEGER(mem_read_addr_temp(ADDR_WIDTH - 1 downto 0))).state = SHARED_STATE then -- If block is shared and current node is the home
							-- TODO: Invalid all shared copy and send AckCount to the requestor
							-- TODO: Send can be with multicast
							current_s <= idle;
						else            -- The block is already modified
							-- TODO: Fwd-GetM to the owner
							current_s <= idle;
						end if;
					else                -- The block is handled by another node
						-- Send mex to the home node
						router_valid_out <= '1';

						-- Create the message body: Dest + Source + Message type + Block Address Request
						--router_data_out  <= core_mex_temp(MEM_ADDR_WIDTH - 1 downto MEM_ADDR_WIDTH - 1 - f_log2(DIRECTORIES_N)) & CONV_STD_LOGIC_VECTOR(DIRECTORY_ID, f_log2(DIRECTORIES_N)) & FWD_GET_S & core_mex_temp(MEM_ADDR_WIDTH - 1 - f_log2(DIRECTORIES_N) - 1 downto 0);
						home_node <= mem_read_addr_temp(BLOCK_WIDTH - 1 downto BLOCK_WIDTH - f_log2(DIRECTORIES_N));
						current_s <= wait_remote_getM;
					end if;

				when Fwd_PutM =>
					-- Send mex to the home node
					router_valid_out <= '1';

					-- Create the message body: Message type + Source + Dest + Block Address Request + Data
					router_data_out <= FWD_PUT_M & CONV_STD_LOGIC_VECTOR(DIRECTORY_ID, f_log2(DIRECTORIES_N)) & mem_write_addr_temp & mem_data_out_temp;
					home_node       <= mem_write_addr_temp(BLOCK_WIDTH - 1 downto BLOCK_WIDTH - f_log2(DIRECTORIES_N));
					current_s       <= wait_Fwd_PutM;

				when Fwd_GetM =>
					current_s <= idle;

				when wait_Fwd_PutM =>
					current_s <= idle;

				when memory_delay =>
					current_s <= next_s;

				when set_sharer =>
					directory(CONV_INTEGER(mem_read_addr_temp(ADDR_WIDTH - 1 downto 0))).sharer(requestor_id) <= '1';

					current_s <= memory_delay; -- Wait 1 clock cycle for memory response
					next_s    <= load_mem;

			end case;

		end if;
	end process;

end architecture RTL;
