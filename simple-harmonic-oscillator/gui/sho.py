import pygame, sys
import numpy as np
import subprocess
import time
import json
from timeit import default_timer as timer

# text box initialization
def update_message (message):
	font = pygame.font.Font(None, 24)
	text = font.render(message, 1, (0, 0, 0))
	text_rect = text.get_rect(center =(WIDTH / 2, HEIGHT-50))
	screen.fill ((255,255,255), (0, HEIGHT-100, WIDTH, 100))
	screen.blit(text, text_rect)

	pygame.display.update()

# utility function to execute shell command and parse result
def subprocess_run (cmd):
	result = subprocess.run(cmd, stdout=subprocess.PIPE)
	result = result.stdout.decode('utf-8')[:-1] # remove trailing newline
	return result

# redraw the screen and the mass at new x location
def update_figures(ball_x):
	screen.fill (BG_COLOR, (0, 0, WIDTH, HEIGHT-100)) # reset screen first

	# draw the point mass
	pygame.draw.circle(
		screen,
		BALL_COLOR,
		(ball_x, BALL_Y), # center coordinate
		BALL_RADIUS,
		0 # fill the circle
	)

	# draw the spring for fun
	spring_circle_first_x = SPRING_CIRCLE_RADIUS
	spring_circle_last_x = ball_x - BALL_RADIUS - SPRING_CIRCLE_RADIUS
	spring_circle_distance = (spring_circle_last_x - spring_circle_first_x)/(N_SPRING_CIRCLE-1)

	spring_circle_x = spring_circle_first_x
	for i in range(N_SPRING_CIRCLE):
		pygame.draw.circle(
			screen,
			SPRING_COLOR,
			(spring_circle_x, BALL_Y), # center coordinate
			SPRING_CIRCLE_RADIUS,
			1
		)
		spring_circle_x += spring_circle_distance

	pygame.display.update()

# scene setup
WIDTH = 600
HEIGHT = 600+100
BALL_RADIUS = 30
SPRING_CIRCLE_RADIUS = 10
N_SPRING_CIRCLE = 20
MESSAGE = "Simple Harmonic Oscillator on StarkNet LFG"

BG_COLOR = (25, 25, 112)
BALL_COLOR = (239, 231, 200)
SPRING_COLOR = (239, 231, 200)

BALL_X_OFFSET = 300
BALL_Y = 300

# contract setup
CONTRACT_ADDRESS = '0x3280705f884bb08c0fd6c53f67e51d1b06c8118397f68234072a78a63b13c9c'
SCALE_FP = 10000 # for fixed-point arithmetic
PRIME = 3618502788666131213697322783095070105623107215331596699973092056135872020481
PRIME_HALF = PRIME//2

pygame.init()
screen = pygame.display.set_mode( (WIDTH, HEIGHT) )
pygame.display.set_caption( 'SHO' )
screen.fill( BG_COLOR )

AMPLITUDE = 100
SCALE_X = (WIDTH/2.-BALL_RADIUS*2)/100
x = AMPLITUDE
xd = 0 # stationary at start

t_fp  = int( 0 * SCALE_FP )
dt_fp = int( 0.02 * SCALE_FP )
x_fp  = int( x * SCALE_FP )
xd_fp = int( xd * SCALE_FP )

update_figures(ball_x = BALL_X_OFFSET + x*SCALE_X)
update_message(MESSAGE)

while True:
	# retrieve N sample from contract
	N = 100
	print(f'> Begin retrieval of {N} coordinates from StarkNet rk4 integrator.')

	x_fp_s = [x_fp]
	xd_fp_s = [xd_fp]
	for i in range(N):

		# sending side must mod P to send only positive felt values; receiving side could receive negative value
		x_fp = x_fp if x_fp>=0 else x_fp+PRIME
		xd_fp = xd_fp if xd_fp>=0 else xd_fp+PRIME

		cmd = f"starknet call --network=alpha --address {CONTRACT_ADDRESS} --abi sho_contract_abi.json " + \
			f"--function query_next_given_coordinates --inputs {t_fp} {dt_fp} {x_fp} {xd_fp}"
		cmd = cmd.split(' ')
		result = subprocess_run(cmd)

		result = result.split(' ')
		x_fp = int(result[0])
		xd_fp = int(result[1])
		t_fp += dt_fp

		x_fp_s.append( x_fp )
		xd_fp_s.append( xd_fp )
		print(f'> {i+1}th/{N} coordinate retrieved from StarkNet rk4 integrator.')
	print()

	x_s = [x_fp/SCALE_FP for x_fp in x_fp_s]
	print('> printing all retrieved coordinates: {x_s}\n')

	# saving the last coordinate for next loop
	x_fp = x_fp_s[-1]
	xd_fp = xd_fp_s[-1]

	# render animation from retrieved coordinates
	print('>>> Begin animation rendering.')
	for i in range(N):
		update_figures(ball_x = BALL_X_OFFSET + x_s[i]*SCALE_X)
		update_message(MESSAGE)
		time.sleep(0.05)

	# check for quit() event
	for event in pygame.event.get():
		if event.type == pygame.QUIT:
			sys.exit()

